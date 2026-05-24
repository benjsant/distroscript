#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_writing"
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
  command -v pandoc &>/dev/null     && pandoc --version | head -1 | sed 's/^/  [ok] /' || echo '  [!!] pandoc manquant'
  command -v xelatex &>/dev/null    && echo '  [ok] xelatex'   || echo '  [!!] xelatex manquant'
  command -v lualatex &>/dev/null   && echo '  [ok] lualatex'  || echo '  [!!] lualatex manquant'
  command -v biber &>/dev/null      && echo '  [ok] biber'     || echo '  [!!] biber manquant'
  command -v marp &>/dev/null       && echo '  [ok] marp'      || echo '  [!!] marp manquant'
  command -v vale &>/dev/null       && echo '  [ok] vale'      || echo '  [!!] vale manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'        || echo '  [!!] gh manquant'
" || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
