#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_devops"
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
cp "$LIB_DIR/fetch.sh" "$HOME_DIR/"

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
  command -v kubectl &>/dev/null    && echo '  [ok] kubectl'    || echo '  [!!] kubectl manquant'
  command -v helm &>/dev/null       && echo '  [ok] helm'       || echo '  [!!] helm manquant'
  command -v terraform &>/dev/null  && echo '  [ok] terraform'  || echo '  [!!] terraform manquant'
  command -v ansible &>/dev/null    && echo '  [ok] ansible'    || echo '  [!!] ansible manquant'
  command -v k9s &>/dev/null        && echo '  [ok] k9s'        || echo '  [!!] k9s manquant'
  command -v kustomize &>/dev/null  && echo '  [ok] kustomize'  || echo '  [!!] kustomize manquant'
  command -v kind &>/dev/null       && echo '  [ok] kind'       || echo '  [!!] kind manquant'
  command -v aws &>/dev/null        && echo '  [ok] aws'        || echo '  [!!] aws manquant'
  command -v gcloud &>/dev/null     && echo '  [ok] gcloud'     || echo '  [!!] gcloud manquant'
  command -v az &>/dev/null         && echo '  [ok] az'         || echo '  [!!] az manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'         || echo '  [!!] gh manquant'
" 2>/dev/null || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
