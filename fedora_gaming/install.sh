#!/bin/bash
set -euo pipefail

BOX_NAME="fedora_gaming"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

# Dossier de jeux, monté dans la box et VOLONTAIREMENT hors du home de la box :
# il survit à une suppression/recréation du conteneur. C'est lui (avec le home)
# qu'on recopie pour migrer vers une autre machine.
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

echo "Dossier de jeux : $GAMES_DIR"
echo ""

### --- Capacités de l'hôte -------------------------------------------------
# Aucune de ces vérifications n'est bloquante : la box doit s'installer sur un
# système fraîchement installé, quitte à perdre une fonctionnalité secondaire.
# (L'ancienne version faisait exit 1 ici, ce qui la rendait ininstallable
# précisément dans le cas où on en a le plus besoin.)

XDG_RUNTIME_DIR="$(detect_xdg_runtime)"
DBUS_SOCKET="${XDG_RUNTIME_DIR}/bus"

HAS_DBUS=0
if [ -S "$DBUS_SOCKET" ]; then
  HAS_DBUS=1
else
  echo "⚠ Bus D-Bus utilisateur absent ($DBUS_SOCKET)."
  echo "  Les notifications et l'intégration bureau seront limitées."
  echo "  Corrigeable après coup : systemctl --user start dbus, puis relancer ce script."
fi

HAS_SYSTEMD=0
if can_run_systemd_in_container; then
  HAS_SYSTEMD=1
else
  echo "⚠ Délégation cgroups v2 absente : la box sera créée sans systemd."
  echo "  Conséquence : gamemode ne pourra pas lancer son daemon (gamemoded)."
  echo "  Tout le reste (Steam, Lutris, Wine, émulateurs) fonctionne normalement."
  echo "  Pour l'activer plus tard : /etc/systemd/system/user@.service.d/delegate.conf"
  echo "    [Service]"
  echo "    Delegate=yes"
fi

# Le passage GPU NVIDIA injecte les libs du driver hôte : leur version doit
# correspondre exactement. Sur AMD/Intel le rendu passe par mesa dans la box,
# sans contrainte de version.
if command -v lspci &>/dev/null && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
  if ! has_nvidia_container_toolkit; then
    echo ""
    echo "⚠ GPU NVIDIA détecté mais nvidia-container-toolkit absent."
    echo "  Sans lui, aucune accélération 3D dans la box : les jeux ne tourneront pas."
    confirm "  Continuer quand même ?" || { echo "Annulé."; exit 1; }
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

# Pas de suffixe :z : distrobox passe --security-opt label=disable, donc le
# conteneur n'est pas confiné par SELinux. ":z" ne servirait à rien et
# déclencherait un réétiquetage récursif de GAMES_DIR : potentiellement des
# centaines de Go de bibliothèque Steam.

EXTRA_FLAGS=(
  --device /dev/dri
  --device /dev/snd
  --device /dev/input
  --volume="${GAMES_DIR}:${GAMES_DIR}"
)

# Socket audio (PipeWire/PulseAudio) + bus session : c'est ce qui donne le son
# et l'intégration bureau. Sans XDG_RUNTIME_DIR, pas de son.
EXTRA_FLAGS+=(--volume="${XDG_RUNTIME_DIR}:${XDG_RUNTIME_DIR}")
if [ "$HAS_DBUS" -eq 1 ]; then
  EXTRA_FLAGS+=(--env=DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_SOCKET}")
fi
if [ -S /run/dbus/system_bus_socket ]; then
  EXTRA_FLAGS+=(--volume="/run/dbus/system_bus_socket:/run/dbus/system_bus_socket")
fi

# /dev/uinput : manettes virtuelles (antimicrox, remapping)
[ -e /dev/uinput ] && EXTRA_FLAGS+=(--device /dev/uinput)

# Alignement des GID hôte pour l'accès aux périphériques : sans ça,
# l'utilisateur de la box ne peut pas lire /dev/dri/renderD* ni /dev/input/*
for grp in render input audio video; do
  gid="$(getent group "$grp" 2>/dev/null | awk -F: '{print $3}')"
  [ -n "$gid" ] && EXTRA_FLAGS+=(--group-add="$gid")
done

# --nvidia si le toolkit est là (detect_nvidia ajoute aussi /dev/dri, déjà présent)
if has_nvidia_container_toolkit && command -v lspci &>/dev/null \
   && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
  EXTRA_FLAGS+=(--nvidia)
fi

INIT_FLAGS=()
if [ "$HAS_SYSTEMD" -eq 1 ]; then
  INIT_FLAGS=(--init --additional-packages "systemd")
fi

### --- Création ------------------------------------------------------------
echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$FEDORA_IMAGE" \
  "${INIT_FLAGS[@]}" \
  --home "$HOME_DIR" \
  --additional-flags "${EXTRA_FLAGS[*]}"

echo "Lancement du post-install..."
distrobox enter "$BOX_NAME" -- bash -c "bash ~/post_install.sh '$GAMES_DIR'"

### --- Vérification --------------------------------------------------------
echo ""
echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -ic '
  for c in steam lutris heroic wine winetricks mangohud gamescope; do
    command -v "$c" &>/dev/null && echo "  [ok] $c" || echo "  [!!] $c manquant"
  done
' 2>/dev/null || true

echo ""
echo "Accélération 3D :"
distrobox enter "$BOX_NAME" -- bash -ic '
  if command -v vulkaninfo &>/dev/null; then
    vulkaninfo --summary 2>/dev/null | grep -E "deviceName|driverName" | sed "s/^\s*/  /" \
      || echo "  [!!] Vulkan ne trouve aucun GPU : vérifiez les drivers de l\''hôte"
  fi
  command -v glxinfo &>/dev/null && glxinfo -B 2>/dev/null | grep -E "OpenGL renderer" | sed "s/^/  /" || true
' 2>/dev/null || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
echo ""
echo "  Lanceurs exportés vers le menu de l'hôte (Steam, Lutris, Heroic…)."
echo "  Sinon : distrobox enter $BOX_NAME -- steam"
echo ""
echo "  Migration vers une autre machine : copiez $HOME_DIR et $GAMES_DIR,"
echo "  puis relancez ce script : la box est jetable, votre état ne l'est pas."
[ "$HAS_SYSTEMD" -eq 0 ] && echo "  Rappel : gamemode indisponible (pas de systemd dans la box)."
exit 0
