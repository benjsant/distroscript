#!/bin/bash
set -euo pipefail

source ~/versions.sh

MODE="${1:-cpu}"

echo "🔧 Mise à jour du système et installation des paquets de base..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installation des dépendances nécessaires (pyenv, build tools)..."
if [ ! -f ~/packages.txt ]; then
  echo "❌ Fichier ~/packages.txt introuvable."
  exit 1
fi
grep -v '^\s*#' ~/packages.txt | grep -v '^\s*$' | xargs -r sudo apt install -y

if ! command -v ollama &>/dev/null; then
  echo "🧠 Installation d'Ollama..."
else
  echo "🔁 Ollama déjà installé, mise à jour..."
fi
curl -fsSL https://ollama.com/install.sh | sh

echo "🐍 Installation / mise à jour de pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
  curl https://pyenv.run | bash
else
  echo "🔁 pyenv déjà installé, mise à jour..."
  git -C "$HOME/.pyenv" pull
fi

echo "🔄 Configuration de pyenv dans ~/.bashrc..."
if ! grep -q 'PYENV_ROOT' ~/.bashrc; then
  echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.bashrc
  echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
  echo 'eval "$(pyenv init -)"' >> ~/.bashrc
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

echo "📦 Installation de la dernière version stable de Python..."
LATEST_PYTHON=$(pyenv install --list | grep -E '^\s*3\.(9|10|11|12|13)\.[0-9]+$' | tail -1 | tr -d ' ') || true
if [ -z "$LATEST_PYTHON" ]; then
  echo "❌ Impossible de déterminer la version Python à installer."
  exit 1
fi
echo "🐍 Version sélectionnée : $LATEST_PYTHON"
pyenv install -s "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"

# Alias VS Code pour distrobox (user namespace)
if ! grep -q "alias code=" ~/.bashrc; then
    echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

echo "🔍 Vérification VS Code..."
code --version && echo "✅ VS Code opérationnel." \
    || echo "⚠️ VS Code installé mais non fonctionnel (essayez manuellement : code --no-sandbox)"


### ⚡ uv — gestionnaire de venvs et paquets
if ! command -v uv &>/dev/null && [ ! -f "$HOME/.local/bin/uv" ]; then
    echo "⚡ Installation de uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    if ! grep -q ‘HOME/.local/bin’ ~/.bashrc; then
        echo ‘export PATH="$HOME/.local/bin:$PATH"’ >> ~/.bashrc
    fi
else
    echo "✅ uv déjà installé."
fi
export PATH="$HOME/.local/bin:$PATH"

### 🎮 Configuration GPU et installation PyTorch
echo "🎮 Configuration GPU : $MODE"
case "$MODE" in
  nvidia)
    echo "🟢 Vérification GPU NVIDIA..."
    nvidia-smi 2>/dev/null && echo "✅ GPU NVIDIA opérationnel." \
      || echo "⚠️ nvidia-smi non disponible — vérifiez que les drivers NVIDIA sont installés sur l’hôte"
    echo "🔥 Installation de PyTorch avec support CUDA..."
    pip install torch torchvision torchaudio --index-url "$TORCH_CUDA_INDEX"
    echo "🔍 Test PyTorch CUDA..."
    python3 -c "import torch; print(‘  ✅ PyTorch’, torch.__version__, ‘| CUDA disponible:’, torch.cuda.is_available())" \
      || echo "⚠️ PyTorch installé mais test échoué"
    ;;
  rocm)
    echo "🔴 Configuration ROCm..."
    ROCM_MOUNT=$(find /opt -maxdepth 1 -type d -name "rocm*" 2>/dev/null | sort | tail -1)
    if [ -n "$ROCM_MOUNT" ]; then
      if ! grep -q "$ROCM_MOUNT/bin" ~/.bashrc; then
        echo "export PATH=\"\$PATH:$ROCM_MOUNT/bin\"" >> ~/.bashrc
        echo "export LD_LIBRARY_PATH=\"\${LD_LIBRARY_PATH:-}:$ROCM_MOUNT/lib\"" >> ~/.bashrc
      fi
      export PATH="$PATH:$ROCM_MOUNT/bin"
      echo "🔍 Vérification ROCm..."
      rocm-smi 2>/dev/null && echo "✅ GPU ROCm opérationnel." \
        || echo "⚠️ rocm-smi non disponible — vérifiez les drivers ROCm sur l’hôte"
    else
      echo "⚠️ Dossier ROCm non trouvé dans /opt"
    fi
    echo "🔥 Installation de PyTorch avec support ROCm..."
    pip install torch torchvision torchaudio --index-url "$TORCH_ROCM_INDEX"
    echo "🔍 Test PyTorch ROCm..."
    python3 -c "import torch; print(‘  ✅ PyTorch’, torch.__version__)" \
      || echo "⚠️ PyTorch installé mais test échoué"
    ;;
  cpu)
    echo "💻 Mode CPU — installation de PyTorch (CPU uniquement)..."
    pip install torch torchvision torchaudio --index-url "$TORCH_CPU_INDEX"
    echo "🔍 Test PyTorch CPU..."
    python3 -c "import torch; print(‘  ✅ PyTorch’, torch.__version__, ‘| CPU only’)" \
      || echo "⚠️ PyTorch installé mais test échoué"
    ;;
  *)
    echo "⚠️ Mode GPU inconnu : $MODE"
    ;;
esac

### 🎨 Prompt personnalisé
if ! grep -q 'PS1=.*📦' ~/.bashrc; then
    echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

### 🐚 Configuration Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
    echo "🐚 Création d'un ~/.zshrc minimal..."
    cat > ~/.zshrc << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
    chsh -s "$(which zsh)" 2>/dev/null || true
    echo "✅ Zsh configuré comme shell par défaut."
fi

echo ""
echo "✅ Installation terminée !"
echo "   🧠 Ollama       — ollama pull <modèle>"
echo "   🐍 Python       — $LATEST_PYTHON via pyenv"
echo "   🔥 PyTorch      — mode $MODE"
echo "   ⚡ uv           — uv venv / uv pip install"
echo "   🐙 GitHub       — gh auth login"
