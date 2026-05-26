#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

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

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF

echo "Installation terminée. n8n $(n8n --version 2>/dev/null || echo 'version inconnue')"
echo "Lancez n8n avec : distrobox enter ubuntu_dev_n8n -- n8n start"
