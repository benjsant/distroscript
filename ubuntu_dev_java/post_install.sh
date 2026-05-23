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

# SDKMAN — gestion multi-versions JDK/Maven/Gradle/Spring
if [ ! -d "$HOME/.sdkman" ]; then
  echo "Installation de SDKMAN..."
  curl -s "https://get.sdkman.io?rcupdate=false" | bash
fi

# shellcheck disable=SC1091
export SDKMAN_DIR="$HOME/.sdkman"
source "$SDKMAN_DIR/bin/sdkman-init.sh"

# Mode non interactif (sinon SDKMAN demande confirmation à chaque install)
yes() { command yes "$@"; }
sdkman_auto_answer=true
sdkman_selfupdate_enable=false

# JDK Temurin LTS (21) + 17 pour compat
JDK_LTS="21.0.5-tem"
JDK_PREV_LTS="17.0.13-tem"

install_sdk() {
  local candidate="$1" version="$2"
  if ! sdk list "$candidate" 2>/dev/null | grep -q "$version"; then
    echo "[$candidate] version $version inconnue de SDKMAN — j'utilise la dernière disponible."
    sdk install "$candidate" </dev/null
  else
    sdk install "$candidate" "$version" </dev/null || true
  fi
}

install_sdk java "$JDK_LTS"
install_sdk java "$JDK_PREV_LTS"
sdk default java "$JDK_LTS" </dev/null

sdk install maven   </dev/null || true
sdk install gradle  </dev/null || true
sdk install springboot </dev/null || true

# .bashrc — SDKMAN ajoute son hook automatiquement, mais on garantit
if ! grep -q 'SDKMAN_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
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
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
  chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation Java terminée. $(java --version | head -1)"
