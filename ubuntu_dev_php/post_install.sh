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

setup_local_bin

# Composer (installer officiel — vérifie le hash)
if ! command -v composer &>/dev/null; then
  echo "Installation de Composer..."
  EXPECTED_HASH="$(curl -fsSL https://composer.github.io/installer.sig)"
  curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
  ACTUAL_HASH="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
  if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Hash Composer invalide — abandon." >&2
    rm -f /tmp/composer-setup.php
    exit 1
  fi
  php /tmp/composer-setup.php --install-dir="$LOCAL_BIN" --filename=composer
  rm -f /tmp/composer-setup.php
fi

export PATH="$LOCAL_BIN:$HOME/.config/composer/vendor/bin:$PATH"

# Symfony CLI
if ! command -v symfony &>/dev/null; then
  echo "Installation de Symfony CLI..."
  curl -fsSL https://get.symfony.com/cli/installer | bash
  if [ -d "$HOME/.symfony5/bin" ]; then
    ln -sf "$HOME/.symfony5/bin/symfony" "$LOCAL_BIN/symfony"
  fi
fi

# Laravel installer
if ! command -v laravel &>/dev/null; then
  echo "Installation du Laravel installer..."
  composer global require laravel/installer
fi

# NVM + Node (pour Vite/Mix)
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installation de NVM $NVM_VERSION..."
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if ! command -v node &>/dev/null; then
  nvm install --lts
fi

# Configuration xdebug : mode debug,develop (pas coverage par défaut)
XDEBUG_INI="$(php --ini 2>/dev/null | grep -i xdebug | awk -F': ' '{print $NF}' | head -1 || true)"
if [ -n "$XDEBUG_INI" ] && [ -f "$XDEBUG_INI" ] && ! grep -q '^xdebug.mode' "$XDEBUG_INI"; then
  echo "xdebug.mode=develop,debug,trace" | sudo tee -a "$XDEBUG_INI" >/dev/null
  echo "xdebug.client_host=127.0.0.1"   | sudo tee -a "$XDEBUG_INI" >/dev/null
  echo "xdebug.start_with_request=yes"  | sudo tee -a "$XDEBUG_INI" >/dev/null
fi

# .bashrc
if ! grep -q 'NVM_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
fi

if ! grep -q 'composer/vendor/bin' ~/.bashrc; then
  echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> ~/.bashrc
fi

setup_prompt_and_aliases

if ! grep -q "alias php-serve=" ~/.bashrc; then
  echo "alias php-serve='php -S 127.0.0.1:8000 -t public'" >> ~/.bashrc
fi

setup_zsh_with_body <<'EOF'
export PATH="$HOME/.config/composer/vendor/bin:$PATH"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
alias php-serve='php -S 127.0.0.1:8000 -t public'
EOF

echo "Installation PHP terminée. $(php -v | head -1)"
