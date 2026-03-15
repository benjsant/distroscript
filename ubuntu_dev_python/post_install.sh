#!/bin/bash
set -euo pipefail

source ~/versions.sh

PACKAGE_FILE="$HOME/packages.txt"

echo "📂 Chemin du fichier : $PACKAGE_FILE"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "❌ Fichier packages.txt introuvable."
  exit 1
fi

echo "🔧 Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installation des paquets de base..."
echo "📜 Lecture du fichier packages.txt..."
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt install -y

echo "🐍 Installation / mise à jour de pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
  curl https://pyenv.run | bash
else
  echo "🔁 pyenv déjà installé, mise à jour..."
  git -C "$HOME/.pyenv" pull
fi

echo "🔄 Configuration de pyenv dans ~/.bashrc..."
if ! grep -q ‘PYENV_ROOT’ ~/.bashrc; then
  echo ‘export PYENV_ROOT="$HOME/.pyenv"’ >> ~/.bashrc
  echo ‘export PATH="$PYENV_ROOT/bin:$PATH"’ >> ~/.bashrc
  echo ‘eval "$(pyenv init --path)"’ >> ~/.bashrc
  echo ‘eval "$(pyenv init -)"’ >> ~/.bashrc
fi

### 🔧 NVM + Node.js LTS
if [ ! -d "$HOME/.nvm" ]; then
    echo "🌐 Installation de NVM et Node.js LTS..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
else
    echo "✅ NVM déjà installé."
fi

# Charger NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Installer Node LTS si pas déjà installé
if ! command -v node &>/dev/null; then
    nvm install --lts
fi

### 🎨 Prompt personnalisé
if ! grep -q 'PS1=.*📦' ~/.bashrc; then
    echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

# 🐍 Initialisation de pyenv dans le shell
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

echo "🐍 Installation de Python $PYTHON_VERSION..."
pyenv install -s "$PYTHON_VERSION"
pyenv global "$PYTHON_VERSION"

echo "✅ Python configuré avec pyenv"

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
    if ! grep -q 'HOME/.local/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
else
    echo "✅ uv déjà installé."
fi
export PATH="$HOME/.local/bin:$PATH"

### 🐚 Configuration Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
    echo "🐚 Création d'un ~/.zshrc minimal..."
    cat > ~/.zshrc << 'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
    chsh -s "$(which zsh)" 2>/dev/null || true
    echo "✅ Zsh configuré comme shell par défaut."
fi

echo ""
echo "✅ Environnement Python prêt !"
echo "💡 Commandes utiles :"
echo "   pyenv install <version>   — installer une version Python"
echo "   uv venv                   — créer un venv dans le dossier courant"
echo "   uv pip install <paquet>   — installer un paquet dans le venv actif"
echo "   gh auth login             — s'authentifier à GitHub"
