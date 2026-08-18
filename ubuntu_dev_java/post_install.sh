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
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt-get install -y

# SDKMAN : gestion multi-versions JDK/Maven/Gradle/Spring
if [ ! -d "$HOME/.sdkman" ]; then
  echo "Installation de SDKMAN..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -s "https://get.sdkman.io?rcupdate=false" | bash
fi

# Mode non interactif AVANT le sourcing (SDKMAN lit ces vars depuis son config)
if [ -f "$HOME/.sdkman/etc/config" ]; then
  sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$HOME/.sdkman/etc/config"
  sed -i 's/^sdkman_selfupdate_feature=.*/sdkman_selfupdate_feature=false/' "$HOME/.sdkman/etc/config"
fi

# shellcheck disable=SC1091
export SDKMAN_DIR="$HOME/.sdkman"
source "$SDKMAN_DIR/bin/sdkman-init.sh"

# JDK Temurin LTS (21) + 17 pour compat
JDK_LTS="21.0.5-tem"
JDK_PREV_LTS="17.0.13-tem"

install_sdk() {
  local candidate="$1" version="$2"
  if ! sdk list "$candidate" 2>/dev/null | grep -q "$version"; then
    echo "[$candidate] version $version inconnue de SDKMAN : j'utilise la dernière disponible."
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

# .bashrc : SDKMAN ajoute son hook automatiquement, mais on garantit
if ! grep -q 'SDKMAN_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
EOF
fi

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
EOF

echo "Installation Java terminée. $(java --version | head -1)"
