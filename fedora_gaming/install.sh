#!/bin/bash
set -euo pipefail

### 📌 Configuration
BOX_NAME="fedora_gaming"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
enable_logging "$LOG_FILE"
print_host_summary

### ✅ Résoudre le runtime XDG et le bus D-Bus de manière portable
XDG_RUNTIME_DIR="$(detect_xdg_runtime)"
DBUS_SOCKET="${XDG_RUNTIME_DIR}/bus"

if [ ! -S "$DBUS_SOCKET" ]; then
  echo "❌ DBus utilisateur non détecté à $DBUS_SOCKET"
  echo "💡 Ouvre une session graphique ou lance : systemctl --user start dbus"
  exit 1
fi

### ⚠️ systemd-in-container exige cgroups v2 délégués
if ! can_run_systemd_in_container; then
  echo "❌ Délégation cgroups v2 absente — fedora_gaming nécessite systemd."
  echo "💡 Ubuntu/Mint : créer /etc/systemd/system/user@.service.d/delegate.conf avec :"
  echo "   [Service]"
  echo "   Delegate=yes"
  echo "   puis redémarrer la session utilisateur."
  exit 1
fi

check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

### 📁 Préparer le dossier home
mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/setup_repos.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/config_amd.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/install_packages.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"

### 🔧 Préparer les flags hôte-spécifiques
SEL="$(selinux_volume_suffix)"
RENDER_GID="$(detect_render_gid)"

EXTRA_FLAGS=(
  --device /dev/dri
  --device /dev/snd
  --device /dev/input
  --cap-add SYS_PTRACE
  --security-opt seccomp=unconfined
  --volume="${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}${SEL}"
  --env=DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_SOCKET}"
)

# Bus système n'est pas toujours présent (Mint avec certaines sessions)
if [ -S /run/dbus/system_bus_socket ]; then
  EXTRA_FLAGS+=(--volume="/run/dbus/system_bus_socket:/run/dbus/system_bus_socket${SEL}")
fi

# Aligner le GID render pour que l'utilisateur du conteneur lise /dev/dri/renderD*
if [ -n "$RENDER_GID" ]; then
  EXTRA_FLAGS+=(--group-add="$RENDER_GID")
fi

### 🚧 Création de la Distrobox
echo "🎮 Création de la Distrobox Fedora pour le gaming..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$FEDORA_IMAGE" \
  --init \
  --home "$HOME_DIR" \
  --additional-flags "${EXTRA_FLAGS[*]}"

### 🚀 Lancer les scripts post-install
echo "⚙️ Lancement des scripts post-install dans la Distrobox..."

distrobox enter "$BOX_NAME" -- bash -c "bash ~/setup_repos.sh && bash ~/config_amd.sh && bash ~/install_packages.sh"

echo ""
echo "✅ Distrobox '$BOX_NAME' prête à l'emploi !"
echo "👉 Entre dans l'environnement avec : distrobox enter $BOX_NAME"
echo "📝 Log complet : $LOG_FILE"
