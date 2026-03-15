#!/bin/bash
set -euo pipefail

### 📌 Configuration
BOX_NAME="ubuntu_dev_ia"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
enable_logging "$LOG_FILE"

### 🔍 Détection GPU (NVIDIA ou ROCm)
MODE="cpu"

if command -v lspci &>/dev/null; then
  if lspci | grep -iE 'NVIDIA' >/dev/null 2>&1; then
    MODE="nvidia"
  elif lspci | grep -iE 'AMD|ATI|Radeon' >/dev/null 2>&1 \
    && find /opt -maxdepth 1 -type d -name "rocm*" 2>/dev/null | grep -q .; then
    MODE="rocm"
  fi
fi

if [ "$MODE" = "cpu" ]; then
  echo "⚠️ Aucun GPU NVIDIA ou ROCm détecté."
  read -rp "Voulez-vous continuer en mode CPU ? (o/N) " answer
  if [[ ! "$answer" =~ ^[oO]$ ]]; then
    echo "❌ Installation annulée."
    exit 1
  fi
fi

echo "ℹ️ Mode GPU sélectionné : $MODE"

check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

### 📁 Préparer le dossier home
mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"

### 🧱 Construction des flags selon GPU
EXTRA_FLAGS="--device=/dev/dri"
if [ "$MODE" = "rocm" ]; then
  ROCM_PATH=$(find /opt -maxdepth 1 -type d -name "rocm*" | sort | tail -1)
  if [ -n "$ROCM_PATH" ]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --volume=$ROCM_PATH:$ROCM_PATH"
  else
    echo "⚠️ Mode rocm choisi mais dossier ROCm non trouvé dans /opt"
  fi
elif [ "$MODE" = "nvidia" ]; then
  EXTRA_FLAGS="$EXTRA_FLAGS --nvidia"
fi

### 🚧 Création de la Distrobox
echo "🚀 Création de la Distrobox '$BOX_NAME' avec mode GPU : $MODE"

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  --init \
  --home "$HOME_DIR" \
  --additional-packages "systemd" \
  --additional-flags "$EXTRA_FLAGS"

### 🚀 Lancement du post-install
echo "⚙️ Lancement du post-install dans la Distrobox avec mode GPU : $MODE..."

distrobox enter "$BOX_NAME" -- bash -c "~/post_install.sh $MODE"

### 🔍 Vérification post-install
echo "🔍 Vérification de l'installation..."
distrobox enter "$BOX_NAME" -- bash -c "
  command -v ollama &>/dev/null && echo '  ✅ Ollama' || echo '  ⚠️  Ollama manquant'
  [ -d \$HOME/.pyenv ] && echo '  ✅ pyenv' || echo '  ⚠️  pyenv manquant'
  \$HOME/.pyenv/shims/python3 -c 'import torch; print(\"  ✅ PyTorch\", torch.__version__)' 2>/dev/null || echo '  ⚠️  PyTorch manquant'
  [ -f \$HOME/.local/bin/uv ] && echo '  ✅ uv' || echo '  ⚠️  uv manquant'
  command -v code &>/dev/null && echo '  ✅ VS Code' || echo '  ⚠️  VS Code manquant'
  command -v gh &>/dev/null && echo '  ✅ gh' || echo '  ⚠️  gh manquant'
" || true

echo ""
echo "✅ Distrobox '$BOX_NAME' prête à l'emploi !"
echo "👉 Lance l'environnement avec : distrobox enter $BOX_NAME"
echo "📝 Log complet : $LOG_FILE"
