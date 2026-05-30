#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_java"
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
distrobox enter "$BOX_NAME" -- bash -ic "
  [ -d \$HOME/.sdkman ]                && echo '  [ok] SDKMAN'    || echo '  [!!] SDKMAN manquant'
  command -v java &>/dev/null          && java --version | head -1 | sed 's/^/  [ok] /' || echo '  [!!] java manquant'
  command -v mvn &>/dev/null           && echo '  [ok] maven'     || echo '  [!!] maven manquant'
  command -v gradle &>/dev/null        && echo '  [ok] gradle'    || echo '  [!!] gradle manquant'
  command -v spring &>/dev/null        && echo '  [ok] spring boot cli' || echo '  [!!] spring boot manquant'
  command -v gh &>/dev/null            && echo '  [ok] gh'        || echo '  [!!] gh manquant'
" 2>/dev/null || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
echo "Astuce : 'sdk list java' pour voir les JDK installables, 'sdk install java X.Y.Z-tem' pour Temurin."
