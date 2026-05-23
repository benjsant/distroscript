#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_rust"
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
distrobox enter "$BOX_NAME" -- bash -c "
  command -v rustc &>/dev/null   && rustc --version | sed 's/^/  [ok] /' || echo '  [!!] rustc manquant'
  command -v cargo &>/dev/null   && echo '  [ok] cargo'  || echo '  [!!] cargo manquant'
  command -v rustfmt &>/dev/null && echo '  [ok] rustfmt' || echo '  [!!] rustfmt manquant'
  command -v gh &>/dev/null      && echo '  [ok] gh'     || echo '  [!!] gh manquant'
" || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
