#!/bin/bash
set -euo pipefail

source ~/versions.sh

MODE="${1:-cpu}"

sudo apt update && sudo apt upgrade -y

if [ ! -f ~/packages.txt ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi
grep -v '^\s*#' ~/packages.txt | grep -v '^\s*$' | xargs -r sudo apt install -y

# Ollama
if ! command -v ollama &>/dev/null; then
  echo "Installation d'Ollama..."
else
  echo "Mise à jour d'Ollama..."
fi
curl -fsSL https://ollama.com/install.sh | sh

# pyenv
if [ ! -d "$HOME/.pyenv" ]; then
  echo "Installation de pyenv..."
  curl https://pyenv.run | bash
else
  git -C "$HOME/.pyenv" pull
fi

if ! grep -q 'PYENV_ROOT' ~/.bashrc; then
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
  echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
  echo 'eval "$(pyenv init -)"' >> ~/.bashrc
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

LATEST_PYTHON=$(pyenv install --list | grep -E '^\s*3\.(9|10|11|12|13)\.[0-9]+$' | tail -1 | tr -d ' ') || true
if [ -z "$LATEST_PYTHON" ]; then
  echo "Impossible de déterminer la version Python à installer." >&2
  exit 1
fi
pyenv install -s "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"

# Alias VS Code
if ! grep -q "alias code=" ~/.bashrc; then
    echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

# uv
if ! command -v uv &>/dev/null && [ ! -f "$HOME/.local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    if ! grep -q 'HOME/.local/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
fi
export PATH="$HOME/.local/bin:$PATH"

# PyTorch selon le mode GPU
case "$MODE" in
  nvidia)
    nvidia-smi 2>/dev/null || echo "nvidia-smi non disponible — vérifiez les drivers sur l'hôte" >&2
    pip install torch torchvision torchaudio --index-url "$TORCH_CUDA_INDEX"
    python3 -c "import torch; print('PyTorch', torch.__version__, '| CUDA:', torch.cuda.is_available())" || true
    ;;
  rocm)
    ROCM_MOUNT=$(find /opt -maxdepth 1 -type d -name "rocm*" 2>/dev/null | sort | tail -1)
    if [ -n "$ROCM_MOUNT" ]; then
      if ! grep -q "$ROCM_MOUNT/bin" ~/.bashrc; then
        echo "export PATH=\"\$PATH:$ROCM_MOUNT/bin\"" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=\"\${LD_LIBRARY_PATH:-}:$ROCM_MOUNT/lib\"" >> ~/.bashrc
      fi
      export PATH="$PATH:$ROCM_MOUNT/bin"
      rocm-smi 2>/dev/null || echo "rocm-smi non disponible — vérifiez les drivers ROCm sur l'hôte" >&2
    else
      echo "Dossier ROCm non trouvé dans /opt" >&2
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

# Prompt personnalisé
if ! grep -q 'PS1=.*📦' ~/.bashrc; then
    echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

# Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
    cat > ~/.zshrc << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
    chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation terminée. Python: $LATEST_PYTHON | PyTorch: mode $MODE"
