#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_ia"
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
  read -rp "Aucun GPU NVIDIA/ROCm détecté. Continuer en mode CPU ? (o/N) " answer
  if [[ ! "$answer" =~ ^[oO]$ ]]; then
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

EXTRA_FLAGS=""
detect_nvidia  # ajoute /dev/dri + --nvidia si toolkit présent
SEL="$(selinux_volume_suffix)"

if [ "$MODE" = "rocm" ] && [ -n "$ROCM_PATH" ]; then
  EXTRA_FLAGS="$EXTRA_FLAGS --volume=${ROCM_PATH}:${ROCM_PATH}${SEL}"
elif [ "$MODE" = "nvidia" ] && ! has_nvidia_container_toolkit; then
  echo "Mode nvidia demandé mais nvidia-container-toolkit absent — CUDA ne fonctionnera pas dans la box." >&2
fi

# systemd dans le conteneur uniquement si la délégation cgroups est disponible
INIT_FLAGS=()
if can_run_systemd_in_container; then
  INIT_FLAGS=(--init --additional-packages "systemd")
else
  echo "Délégation cgroups v2 absente — création sans --init (systemd-in-container indisponible)." >&2
fi

echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  "${INIT_FLAGS[@]}" \
  --home "$HOME_DIR" \
  --additional-flags "$EXTRA_FLAGS"

echo "Lancement du post-install (mode $MODE)..."

distrobox enter "$BOX_NAME" -- bash -c "~/post_install.sh $MODE"

echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -c "
  command -v ollama &>/dev/null         && echo '  [ok] Ollama'   || echo '  [!!] Ollama manquant'
  [ -d \$HOME/.pyenv ]                  && echo '  [ok] pyenv'    || echo '  [!!] pyenv manquant'
  \$HOME/.pyenv/shims/python3 -c 'import torch; print(\"  [ok] PyTorch\", torch.__version__)' 2>/dev/null \
    || echo '  [!!] PyTorch manquant'
  [ -f \$HOME/.local/bin/uv ]           && echo '  [ok] uv'       || echo '  [!!] uv manquant'
  command -v gh &>/dev/null             && echo '  [ok] gh'       || echo '  [!!] gh manquant'
" || true

echo ""
echo "Distrobox '$BOX_NAME' prête. Log : $LOG_FILE"
