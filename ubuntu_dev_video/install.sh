#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_video"
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
  command -v ffmpeg &>/dev/null     && ffmpeg -version | head -1 | sed 's/^/  [ok] /' || echo '  [!!] ffmpeg manquant'
  command -v yt-dlp &>/dev/null     && echo '  [ok] yt-dlp'      || echo '  [!!] yt-dlp manquant'
  command -v mkvmerge &>/dev/null   && echo '  [ok] mkvtoolnix'  || echo '  [!!] mkvtoolnix manquant'
  command -v HandBrakeCLI &>/dev/null && echo '  [ok] HandBrakeCLI' || echo '  [!!] HandBrakeCLI manquant'
  command -v mediainfo &>/dev/null  && echo '  [ok] mediainfo'   || echo '  [!!] mediainfo manquant'
  command -v exiftool &>/dev/null   && echo '  [ok] exiftool'    || echo '  [!!] exiftool manquant'
  [ -x \$HOME/.local/bin/whisper-cli ] && echo '  [ok] whisper.cpp' || echo '  [!!] whisper.cpp manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'          || echo '  [!!] gh manquant'
" || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
