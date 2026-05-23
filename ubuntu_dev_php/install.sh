#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_php"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
force_utf8_locale
enable_logging "$LOG_FILE"
print_host_summary
check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"

EXTRA_FLAGS=""
detect_nvidia

echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  --home "$HOME_DIR" \
  --additional-flags "$EXTRA_FLAGS"

echo "Lancement du post-install..."

distrobox enter "$BOX_NAME" -- bash ~/post_install.sh

echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -lc "
  command -v php &>/dev/null       && php -v | head -1 | sed 's/^/  [ok] /' || echo '  [!!] php manquant'
  command -v composer &>/dev/null  && echo '  [ok] composer'         || echo '  [!!] composer manquant'
  command -v symfony &>/dev/null   && echo '  [ok] symfony cli'      || echo '  [!!] symfony cli manquant'
  command -v laravel &>/dev/null   && echo '  [ok] laravel installer' || echo '  [!!] laravel manquant'
  php -m 2>/dev/null | grep -qi xdebug && echo '  [ok] xdebug'       || echo '  [!!] xdebug manquant'
  command -v gh &>/dev/null        && echo '  [ok] gh'               || echo '  [!!] gh manquant'
" || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
