#!/bin/bash
set -euo pipefail

source ~/versions.sh

echo "🔧 Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installation des paquets de base..."
if [ -f ~/packages.txt ]; then
    grep -v '^\s*#' ~/packages.txt | grep -v '^\s*$' | xargs -r sudo apt install -y
else
    echo "❌ Fichier ~/packages.txt introuvable."
    exit 1
fi

### 🍺 Homebrew
if ! command -v brew &>/dev/null; then
    echo "🍺 Installation de Homebrew..."
    NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "✅ Homebrew déjà installé."
fi

echo "🔄 Ajout de Homebrew au PATH dans ~/.bashrc..."
BREW_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
if ! grep -Fxq "$BREW_LINE" ~/.bashrc; then
    echo "$BREW_LINE" >> ~/.bashrc
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

### 🚀 Hugo
if ! command -v hugo &>/dev/null; then
    echo "📦 Installation de Hugo..."
    brew install hugo
else
    echo "✅ Hugo déjà installé."
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

# Alias VS Code pour distrobox (user namespace)
if ! grep -q "alias code=" ~/.bashrc; then
    echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

echo "🔍 Vérification VS Code..."
code --version && echo "✅ VS Code opérationnel." \
    || echo "⚠️ VS Code installé mais non fonctionnel (essayez manuellement : code --no-sandbox)"

### 🐚 Configuration Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
    echo "🐚 Création d'un ~/.zshrc minimal..."
    cat > ~/.zshrc << 'EOF'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

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
echo "✅ Installation complète ! Tu peux maintenant utiliser Hugo, Node, VS Code, etc."
echo "💡 gh auth login   — pour connecter GitHub"
