#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_dotnet"
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

EXTRA_FLAGS=""
detect_nvidia

echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  --home "$HOME_DIR" \
  --additional-flags "$EXTRA_FLAGS"

echo "Lancement du post-install..."

distrobox enter "$BOX_NAME" -- bash -c 'bash ~/post_install.sh'

echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -lc "
  command -v dotnet &>/dev/null     && dotnet --version | sed 's/^/  [ok] dotnet /' || echo '  [!!] dotnet manquant'
  command -v pwsh &>/dev/null       && pwsh --version | sed 's/^/  [ok] /' || echo '  [!!] pwsh manquant'
  command -v az &>/dev/null         && echo '  [ok] az'      || echo '  [!!] az manquant'
  command -v dotnet-ef &>/dev/null  && echo '  [ok] dotnet-ef' || echo '  [!!] dotnet-ef manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'      || echo '  [!!] gh manquant'
" || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
