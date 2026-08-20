#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi

sudo apt-get update && sudo apt-get upgrade -y
apt_install_from ~/packages_common.txt ~/packages.txt

setup_local_bin

# Composer (installer officiel : vérifie le hash)
if ! box_has_bin composer; then
  echo "Installation de Composer..."
  EXPECTED_HASH="$(curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://composer.github.io/installer.sig)"
  tmp_php="$(mktemp --suffix=.php)"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://getcomposer.org/installer -o "$tmp_php"
  ACTUAL_HASH="$(php -r "echo hash_file('sha384', '$tmp_php');")"
  if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Hash Composer invalide : abandon." >&2
    rm -f "$tmp_php"
    exit 1
  fi
  php "$tmp_php" --install-dir="$LOCAL_BIN" --filename=composer
  rm -f "$tmp_php"
fi

export PATH="$LOCAL_BIN:$HOME/.config/composer/vendor/bin:$PATH"

# Symfony CLI
if ! box_has_bin symfony; then
  echo "Installation de Symfony CLI..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://get.symfony.com/cli/installer | bash
  if [ -d "$HOME/.symfony5/bin" ]; then
    ln -sf "$HOME/.symfony5/bin/symfony" "$LOCAL_BIN/symfony"
  fi
fi

# Laravel installer
if ! box_has_bin laravel; then
  echo "Installation du Laravel installer..."
  composer global require laravel/installer
fi

# NVM + Node (pour Vite/Mix)
# NVM_DIR doit être exporté AVANT l'installeur : depuis la v0.40.4, NVM
# s'installe par défaut dans $XDG_CONFIG_HOME/nvm (~/.config/nvm) et non plus
# dans ~/.nvm. Sans ça, tout le reste du projet cherche au mauvais endroit.
export NVM_DIR="$HOME/.nvm"
# Le dossier doit exister AVANT l'installeur : celui-ci refuse de démarrer si
# NVM_DIR est défini mais absent ("that directory does not exist").
mkdir -p "$NVM_DIR"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "Installation de NVM $NVM_VERSION..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
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
