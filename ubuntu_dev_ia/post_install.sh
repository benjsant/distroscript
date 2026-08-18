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

# 2. Ollama (install ou update : l'installeur officiel gère les deux cas)
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

# 6. Installation de Python via pyenv
# Le plafond de version vient de PyTorch, qui ne publie pas de wheels pour les
# toutes dernières versions de Python : installer 3.14 ici donnerait un torch
# compilé depuis les sources, ou pas de torch du tout. D'où un pin distinct de
# PYTHON_VERSION, centralisé dans versions.sh.
PY_MINORS="$(seq 9 "${IA_PYTHON_MAX_MINOR}" | paste -sd'|')"
LATEST_PYTHON=$(pyenv install --list \
  | grep -E "^[[:space:]]*3\.(${PY_MINORS})\.[0-9]+$" \
  | tail -1 | tr -d ' ') || true
if [ -z "$LATEST_PYTHON" ]; then
  echo "Impossible de déterminer la version Python à installer." >&2
  exit 1
fi
pyenv install -s "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"

# 7. Venv d'expérimentation + PyTorch selon le mode GPU
#
# uv plutôt que pip : c'est l'outil retenu partout ailleurs dans le projet, et
# il est nettement plus rapide sur des wheels PyTorch qui pèsent plusieurs
# centaines de Mo. Le venv isole torch du Python global de pyenv : même motif
# que le profil "data" de ubuntu_dev_python.
IA_VENV="$HOME/ia_env"
if [ ! -d "$IA_VENV" ]; then
  echo "Création du venv $IA_VENV..."
  uv venv "$IA_VENV" --python "$LATEST_PYTHON"
fi

TORCH_INDEX=""
case "$MODE" in
  nvidia)
    nvidia-smi 2>/dev/null || echo "nvidia-smi non disponible : vérifiez les drivers sur l'hôte" >&2
    TORCH_INDEX="$TORCH_CUDA_INDEX"
    ;;
  rocm)
    ROCM_MOUNT=$(find /opt /usr/lib64 /usr/lib -maxdepth 1 -type d -name "rocm*" 2>/dev/null | sort | tail -1)
    if [ -n "$ROCM_MOUNT" ]; then
      if ! grep -q "$ROCM_MOUNT/bin" ~/.bashrc; then
        echo "export PATH=\"\$PATH:$ROCM_MOUNT/bin\"" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=\"\${LD_LIBRARY_PATH:-}:$ROCM_MOUNT/lib\"" >> ~/.bashrc
      fi
      export PATH="$PATH:$ROCM_MOUNT/bin"
      rocm-smi 2>/dev/null || echo "rocm-smi non disponible : vérifiez les drivers ROCm sur l'hôte" >&2
    else
      echo "Dossier ROCm non trouvé" >&2
    fi
    TORCH_INDEX="$TORCH_ROCM_INDEX"
    ;;
  cpu)
    TORCH_INDEX="$TORCH_CPU_INDEX"
    ;;
  *)
    echo "Mode GPU inconnu : $MODE" >&2
    ;;
esac

if [ -n "$TORCH_INDEX" ]; then
  uv pip install --python "$IA_VENV/bin/python" \
    torch torchvision torchaudio --index-url "$TORCH_INDEX"
  "$IA_VENV/bin/python" -c \
    "import torch; print('PyTorch', torch.__version__, '| CUDA:', torch.cuda.is_available())" || true
fi

if ! grep -q "alias ia-env=" ~/.bashrc; then
  echo "alias ia-env='source ~/ia_env/bin/activate'" >> ~/.bashrc
fi

# 8. Prompt, alias, Zsh : en dernier
setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true
alias ia-env='source ~/ia_env/bin/activate'
EOF

echo "Installation terminée. Python: $LATEST_PYTHON | PyTorch: mode $MODE"
echo "Activer le venv PyTorch : ia-env  (ou source ~/ia_env/bin/activate)"
