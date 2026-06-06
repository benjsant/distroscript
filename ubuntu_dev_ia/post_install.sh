#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

MODE="${1:-cpu}"

# 1. Système
sudo apt-get update && sudo apt-get upgrade -y

if [ ! -f ~/packages.txt ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi
grep -v '^\s*#' ~/packages.txt | grep -v '^\s*$' | xargs -r sudo apt-get install -y

setup_local_bin

# 2. Ollama (install ou update — l'installeur officiel gère les deux cas)
echo "Installation / mise à jour d'Ollama..."
curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://ollama.com/install.sh | sh

# 3. pyenv
if [ ! -d "$HOME/.pyenv" ]; then
  echo "Installation de pyenv..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 https://pyenv.run | bash
else
  git -C "$HOME/.pyenv" pull
fi

if ! grep -q 'PYENV_ROOT' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOF
fi

# 4. uv
if ! command -v uv &>/dev/null && [ ! -f "$LOCAL_BIN/uv" ]; then
  echo "Installation de uv..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -LsSf https://astral.sh/uv/install.sh | sh
fi

# 5. Init env pour la suite
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

# 6. Installation de Python via pyenv (dernière 3.9-3.13 dispo)
LATEST_PYTHON=$(pyenv install --list | grep -E '^\s*3\.(9|10|11|12|13)\.[0-9]+$' | tail -1 | tr -d ' ') || true
if [ -z "$LATEST_PYTHON" ]; then
  echo "Impossible de déterminer la version Python à installer." >&2
  exit 1
fi
pyenv install -s "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"

# 7. PyTorch selon le mode GPU
case "$MODE" in
  nvidia)
    nvidia-smi 2>/dev/null || echo "nvidia-smi non disponible — vérifiez les drivers sur l'hôte" >&2
    pip install torch torchvision torchaudio --index-url "$TORCH_CUDA_INDEX"
    python3 -c "import torch; print('PyTorch', torch.__version__, '| CUDA:', torch.cuda.is_available())" || true
    ;;
  rocm)
    ROCM_MOUNT=$(find /opt /usr/lib64 /usr/lib -maxdepth 1 -type d -name "rocm*" 2>/dev/null | sort | tail -1)
    if [ -n "$ROCM_MOUNT" ]; then
      if ! grep -q "$ROCM_MOUNT/bin" ~/.bashrc; then
        echo "export PATH=\"\$PATH:$ROCM_MOUNT/bin\"" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=\"\${LD_LIBRARY_PATH:-}:$ROCM_MOUNT/lib\"" >> ~/.bashrc
      fi
      export PATH="$PATH:$ROCM_MOUNT/bin"
      rocm-smi 2>/dev/null || echo "rocm-smi non disponible — vérifiez les drivers ROCm sur l'hôte" >&2
    else
      echo "Dossier ROCm non trouvé" >&2
    fi
    pip install torch torchvision torchaudio --index-url "$TORCH_ROCM_INDEX"
    python3 -c "import torch; print('PyTorch', torch.__version__)" || true
    ;;
  cpu)
    pip install torch torchvision torchaudio --index-url "$TORCH_CPU_INDEX"
    python3 -c "import torch; print('PyTorch', torch.__version__, '| CPU only')" || true
    ;;
  *)
    echo "Mode GPU inconnu : $MODE" >&2
    ;;
esac

# 8. Prompt, alias, Zsh — en dernier
setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true
EOF

echo "Installation terminée. Python: $LATEST_PYTHON | PyTorch: mode $MODE"
