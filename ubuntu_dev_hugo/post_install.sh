#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

sudo apt update && sudo apt upgrade -y

if [ -f ~/packages.txt ]; then
    grep -v '^\s*#' ~/packages.txt | grep -v '^\s*$' | xargs -r sudo apt install -y
else
    echo "packages.txt introuvable." >&2
    exit 1
fi

# Homebrew
if ! command -v brew &>/dev/null; then
    echo "Installation de Homebrew..."
    NONINTERACTIVE=1 bash -c "$(curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

BREW_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
if ! grep -Fxq "$BREW_LINE" ~/.bashrc; then
    echo "$BREW_LINE" >> ~/.bashrc
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Hugo
if ! command -v hugo &>/dev/null; then
    brew install hugo
fi

# NVM + Node.js LTS
if [ ! -d "$HOME/.nvm" ]; then
    echo "Installation de NVM..."
    curl --retry 3 --retry-delay 2 --connect-timeout 10 -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! command -v node &>/dev/null; then
    nvm install --lts
fi

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF

echo "Installation terminée."
