#!/bin/bash
set -euo pipefail

source ~/versions.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi

sudo apt update && sudo apt upgrade -y
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt install -y

# NVM + Node.js
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installation de NVM $NVM_VERSION..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

nvm install --lts

# n8n
if ! command -v n8n &>/dev/null; then
  echo "Installation de n8n..."
  npm install -g n8n
fi

# .bashrc
if ! grep -q 'NVM_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
fi

if ! grep -q 'PS1=.*📦' ~/.bashrc; then
  echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

if ! grep -q "alias code=" ~/.bashrc; then
  echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

# Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
  cat > ~/.zshrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
  chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation terminée. n8n $(n8n --version 2>/dev/null || echo 'version inconnue')"
echo "Lancez n8n avec : distrobox enter ubuntu_dev_n8n -- n8n start"
