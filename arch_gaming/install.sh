#!/bin/bash
set -euo pipefail

# arch_gaming — box de jeu bâtie sur ghcr.io/ublue-os/steambox, l'image OCI
# gaming maintenue par Universal Blue (successeur de bazzite-arch, archivé en
# mars 2026). Alternative à fedora_gaming : on délègue à des gens dont c'est le
# métier la partie la plus pénible (lib32, audio, couches Vulkan, mesa), et le
# post-install n'ajoute que le manquant.
#
# Arch est ici sans risque pour l'hôte : le conteneur est jetable, l'image est
# construite et testée en amont, et rien n'est installé sur le système.

BOX_NAME="arch_gaming"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

GAMES_DIR="${GAMES_DIR:-$HOME/Games}"

while [ $# -gt 0 ]; do
  case "$1" in
    --games-dir)   GAMES_DIR="${2:-}"; shift 2 ;;
    --games-dir=*) GAMES_DIR="${1#*=}"; shift ;;
    -h|--help)
      echo "Usage: $0 [--games-dir CHEMIN]"
      echo "  --games-dir  Dossier des jeux et préfixes Wine (défaut: ~/Games)"
      exit 0
      ;;
    *)
      echo "Option inconnue : $1" >&2
      exit 1
      ;;
  esac
done

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
force_utf8_locale
enable_logging "$LOG_FILE"
print_host_summary

echo "Image  : $STEAMBOX_IMAGE"
echo "Jeux   : $GAMES_DIR"
echo ""
echo "⚠ L'image pèse environ 11 Go — le premier téléchargement est long."
echo "  En contrepartie, la box est prête sans compiler ni résoudre de dépendances."
echo ""

### --- Capacités de l'hôte -------------------------------------------------
# Aucune vérification n'est bloquante : la box doit s'installer sur un système
# fraîchement installé, quitte à perdre une fonctionnalité secondaire.

XDG_RUNTIME_DIR="$(detect_xdg_runtime)"
DBUS_SOCKET="${XDG_RUNTIME_DIR}/bus"

HAS_DBUS=0
if [ -S "$DBUS_SOCKET" ]; then
  HAS_DBUS=1
else
  echo "⚠ Bus D-Bus utilisateur absent ($DBUS_SOCKET)."
  echo "  Notifications et intégration bureau limitées."
fi

HAS_SYSTEMD=0
if can_run_systemd_in_container; then
  HAS_SYSTEMD=1
else
  echo "⚠ Délégation cgroups v2 absente — box créée sans systemd."
  echo "  Conséquence : gamemode ne pourra pas lancer son daemon (gamemoded)."
  echo "  Tout le reste (Steam, Lutris, Wine, émulateurs) fonctionne normalement."
fi

if command -v lspci &>/dev/null && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
  if ! has_nvidia_container_toolkit; then
    echo ""
    echo "⚠ GPU NVIDIA détecté mais nvidia-container-toolkit absent."
    echo "  Sans lui, aucune accélération 3D dans la box."
    read -rp "  Continuer quand même ? (o/N) " ans
    [[ "$ans" =~ ^[oO]$ ]] || { echo "Annulé."; exit 1; }
  fi
fi

echo ""
check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

### --- Préparation ---------------------------------------------------------
mkdir -p "$HOME_DIR" "$GAMES_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"
cp "$LIB_DIR/shell_setup.sh" "$HOME_DIR/"

SEL="$(selinux_volume_suffix)"

EXTRA_FLAGS=(
  --device /dev/dri
  --device /dev/snd
  --device /dev/input
  --volume="${GAMES_DIR}:${GAMES_DIR}${SEL}"
  --volume="${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}${SEL}"
)

if [ "$HAS_DBUS" -eq 1 ]; then
  EXTRA_FLAGS+=(--env=DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_SOCKET}")
fi
if [ -S /run/dbus/system_bus_socket ]; then
  EXTRA_FLAGS+=(--volume="/run/dbus/system_bus_socket:/run/dbus/system_bus_socket${SEL}")
fi

[ -e /dev/uinput ] && EXTRA_FLAGS+=(--device /dev/uinput)

for grp in render input audio video; do
  gid="$(getent group "$grp" 2>/dev/null | awk -F: '{print $3}')"
  [ -n "$gid" ] && EXTRA_FLAGS+=(--group-add="$gid")
done

if has_nvidia_container_toolkit && command -v lspci &>/dev/null \
   && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
  EXTRA_FLAGS+=(--nvidia)
fi

INIT_FLAGS=()
if [ "$HAS_SYSTEMD" -eq 1 ]; then
  INIT_FLAGS=(--init)
fi

# --unshare-netns : recommandé en amont pour cette image. Indispensable si Steam
# tourne AUSSI sur l'hôte — deux Steam dans le même namespace réseau se
# disputent les mêmes ports.
NETNS_FLAGS=(--unshare-netns)

### --- Création ------------------------------------------------------------
echo "Création de la distrobox '$BOX_NAME' (téléchargement de l'image…)"

distrobox-create \
  --name "$BOX_NAME" \
  --image "$STEAMBOX_IMAGE" \
  --yes \
  "${NETNS_FLAGS[@]}" \
  "${INIT_FLAGS[@]}" \
  --home "$HOME_DIR" \
  --additional-flags "${EXTRA_FLAGS[*]}"

echo "Lancement du post-install..."
distrobox enter "$BOX_NAME" -- bash -c "bash ~/post_install.sh '$GAMES_DIR'"

### --- Vérification --------------------------------------------------------
echo ""
echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -ic '
  for c in steam lutris wine mangohud gamescope umu-run protontricks; do
    command -v "$c" &>/dev/null && echo "  [ok] $c" || echo "  [!!] $c manquant"
  done
' 2>/dev/null || true

echo ""
echo "Accélération 3D :"
distrobox enter "$BOX_NAME" -- bash -ic '
  if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName" | sed "s/^\s*/  /" \
      || echo "  [!!] Vulkan ne trouve aucun GPU"
  fi
' 2>/dev/null || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
echo ""
echo "  Lanceurs exportés vers le menu de l'hôte."
echo "  Sinon : distrobox enter $BOX_NAME -- steam"
echo ""
echo "  Migration : copiez $HOME_DIR et $GAMES_DIR, puis relancez ce script."
[ "$HAS_SYSTEMD" -eq 0 ] && echo "  Rappel : gamemode indisponible (pas de systemd dans la box)."
exit 0
