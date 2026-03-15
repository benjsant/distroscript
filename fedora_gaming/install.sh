#!/bin/bash
set -euo pipefail

### 📌 Configuration
BOX_NAME="fedora_gaming"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"
HOST_UID=$(id -u)
XDG_RUNTIME_DIR="/run/user/${HOST_UID}"
DBUS_SOCKET="${XDG_RUNTIME_DIR}/bus"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
enable_logging "$LOG_FILE"

### ✅ Vérifier D-Bus
if [ ! -S "$DBUS_SOCKET" ]; then
  echo "❌ DBus non détecté à $DBUS_SOCKET"
  echo "💡 Lance une session graphique ou exporte DBus avec : export \$(dbus-launch)"
  exit 1
fi

check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

### 📁 Préparer le dossier home
mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/setup_repos.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/config_amd.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/install_packages.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"

### 🚧 Création de la Distrobox
echo "🎮 Création de la Distrobox Fedora pour le gaming..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$FEDORA_IMAGE" \
  --init \
  --home "$HOME_DIR" \
  --additional-flags "\
    --device /dev/dri \
    --device /dev/snd \
    --device /dev/input \
    --cap-add SYS_PTRACE \
    --security-opt seccomp=unconfined \
    --volume=${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR} \
    --volume=/run/dbus/system_bus_socket:/run/dbus/system_bus_socket \
    --env=DBUS_SESSION_BUS_ADDRESS=unix:path=${DBUS_SOCKET}"

### 🚀 Lancer les scripts post-install
echo "⚙️ Lancement des scripts post-install dans la Distrobox..."

distrobox enter "$BOX_NAME" -- bash -c "bash ~/setup_repos.sh && bash ~/config_amd.sh && bash ~/install_packages.sh"

echo ""
echo "✅ Distrobox '$BOX_NAME' prête à l'emploi !"
echo "👉 Entre dans l'environnement avec : distrobox enter $BOX_NAME"
echo "📝 Log complet : $LOG_FILE"
