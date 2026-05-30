#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_n8n"
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
check_locale_for_ubuntu_box
check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"
cp "$LIB_DIR/shell_setup.sh" "$HOME_DIR/"

echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  --home "$HOME_DIR"

echo "Lancement du post-install..."

distrobox enter "$BOX_NAME" -- bash -c 'bash ~/post_install.sh'

echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -ic "
  command -v node &>/dev/null && echo '  [ok] node '$(node --version 2>/dev/null) || echo '  [!!] node manquant'
  command -v n8n &>/dev/null  && echo '  [ok] n8n'  || echo '  [!!] n8n manquant'
" 2>/dev/null || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
echo "Lancer n8n : distrobox enter $BOX_NAME -- n8n start"
