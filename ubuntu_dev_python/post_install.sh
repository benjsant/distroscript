#!/bin/bash
set -euo pipefail

source ~/versions.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable : $PACKAGE_FILE" >&2
  exit 1
fi

sudo apt update && sudo apt upgrade -y
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt install -y

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

# NVM + Node.js LTS
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installation de NVM..."
  curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

if ! command -v node &>/dev/null; then
    nvm install --lts
fi

# Prompt et alias
if ! grep -q 'PS1=.*📦' ~/.bashrc; then
    echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

if ! grep -q "alias code=" ~/.bashrc; then
    echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

# Python via pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

pyenv install -s "$PYTHON_VERSION"
pyenv global "$PYTHON_VERSION"

# uv
if ! command -v uv &>/dev/null && [ ! -f "$HOME/.local/bin/uv" ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    if ! grep -q 'HOME/.local/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    fi
fi
export PATH="$HOME/.local/bin:$PATH"

# Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
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
fi

echo "Installation terminée."
