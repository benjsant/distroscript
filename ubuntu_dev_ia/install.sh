#!/bin/bash
set -euo pipefail

# Seul environnement Ubuntu à ne pas passer par lib/box_common.sh : il détecte
# le backend GPU (nvidia/rocm/cpu), monte ROCm et active systemd sous condition.
BOX_NAME="ubuntu_dev_ia"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

case "${1:-}" in
  -h|--help)
    echo "Usage: $0"
    echo "Crée la box IA. Le backend GPU (nvidia / rocm / cpu) est détecté"
    echo "automatiquement ; en l'absence de GPU, une confirmation est demandée."
    exit 0
    ;;
  "") ;;
  *)  echo "Option inconnue : $1" >&2; exit 1 ;;
esac

check_not_root
force_utf8_locale
enable_logging "$LOG_FILE"
print_host_summary
check_locale_for_ubuntu_box

# Détection GPU
MODE="cpu"
ROCM_PATH=""

if command -v lspci &>/dev/null; then
  if lspci | grep -iE 'NVIDIA' >/dev/null 2>&1; then
    MODE="nvidia"
  elif lspci | grep -iE 'AMD|ATI|Radeon' >/dev/null 2>&1; then
    if ROCM_PATH="$(detect_rocm_path)"; then
      MODE="rocm"
    fi
  fi
fi

if [ "$MODE" = "cpu" ]; then
  if ! confirm "Aucun GPU NVIDIA/ROCm détecté. Continuer en mode CPU ?"; then
    echo "Annulé." >&2
    exit 1
  fi
fi

echo "Mode GPU : $MODE"

check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"
cp "$LIB_DIR/shell_setup.sh" "$HOME_DIR/"
cp "$LIB_DIR/fetch.sh" "$HOME_DIR/"
cp "$LIB_DIR/packages_common.txt" "$HOME_DIR/"
cp "$SCRIPT_DIR/verify.sh" "$HOME_DIR/"

EXTRA_FLAGS=""
detect_nvidia  # ajoute /dev/dri + --nvidia si toolkit présent
# Pas de suffixe :z (voir selinux_volume_suffix dans lib/common.sh) :
# réétiqueter le dossier ROCm de l'hôte pourrait gêner l'hôte lui-même.

if [ "$MODE" = "rocm" ] && [ -n "$ROCM_PATH" ]; then
  EXTRA_FLAGS="$EXTRA_FLAGS --volume=${ROCM_PATH}:${ROCM_PATH}"
elif [ "$MODE" = "nvidia" ] && ! has_nvidia_container_toolkit; then
  echo "Mode nvidia demandé mais nvidia-container-toolkit absent : CUDA ne fonctionnera pas dans la box." >&2
fi

# systemd dans le conteneur uniquement si la délégation cgroups est disponible
INIT_FLAGS=()
if can_run_systemd_in_container; then
  INIT_FLAGS=(--init --additional-packages "systemd")
else
  echo "Délégation cgroups v2 absente : création sans --init (systemd-in-container indisponible)." >&2
fi

echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  "${INIT_FLAGS[@]}" \
  --home "$HOME_DIR" \
  --additional-flags "$EXTRA_FLAGS"

echo "Lancement du post-install (mode $MODE)..."

distrobox enter "$BOX_NAME" -- bash -c "bash ~/post_install.sh $MODE"

echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -ic "bash ~/verify.sh" 2>/dev/null || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
