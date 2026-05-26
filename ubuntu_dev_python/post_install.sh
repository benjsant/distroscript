#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable : $PACKAGE_FILE" >&2
  exit 1
fi

# 1. Système
sudo apt update && sudo apt upgrade -y
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt install -y

setup_local_bin

# 2. Installation des managers (pyenv, NVM, uv)
if [ ! -d "$HOME/.pyenv" ]; then
  echo "Installation de pyenv..."
  curl https://pyenv.run | bash
else
  git -C "$HOME/.pyenv" pull
fi

if [ ! -d "$HOME/.nvm" ]; then
  echo "Installation de NVM $NVM_VERSION..."
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

if ! command -v uv &>/dev/null && [ ! -f "$LOCAL_BIN/uv" ]; then
  echo "Installation de uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# 3. .bashrc : tous les exports + hooks en un seul bloc
if ! grep -q 'PYENV_ROOT' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOF
fi

if ! grep -q 'NVM_DIR' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOF
fi

# 4. Init env pour la suite du script
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# 5. Installation des runtimes (Python via pyenv, Node via NVM)
pyenv install -s "$PYTHON_VERSION"
pyenv global "$PYTHON_VERSION"

if ! command -v node &>/dev/null; then
  nvm install --lts
fi

# 6. Prompt, alias et Zsh — en dernier
setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$HOME/.local/bin:$PATH"
eval "$(pyenv init -)" 2>/dev/null || true

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF

echo "Installation terminée. Python $(python --version 2>&1)  Node $(node --version 2>/dev/null || echo '(absent)')"
