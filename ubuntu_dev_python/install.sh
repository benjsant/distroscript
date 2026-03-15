#!/bin/bash
set -euo pipefail

### 📌 Configuration
BOX_NAME="ubuntu_dev_python"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
enable_logging "$LOG_FILE"
check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

### 📁 Préparer le dossier home
mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"

### 🎮 Détection GPU NVIDIA
detect_nvidia

### 🧱 Création de la Distrobox
echo "📦 Création de la Distrobox Ubuntu pour le dev Python..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  --home "$HOME_DIR" \
  --additional-flags "$EXTRA_FLAGS"

### 🚀 Exécuter le post-install
echo "⚙️ Lancement du post-install dans la Distrobox..."

distrobox enter "$BOX_NAME" -- bash ~/post_install.sh

### 🔍 Vérification post-install
echo "🔍 Vérification de l'installation..."
distrobox enter "$BOX_NAME" -- bash -c "
  [ -d \$HOME/.pyenv ] && echo '  ✅ pyenv' || echo '  ⚠️  pyenv manquant'
  [ -d \$HOME/.nvm ] && echo '  ✅ NVM' || echo '  ⚠️  NVM manquant'
  [ -f \$HOME/.local/bin/uv ] && echo '  ✅ uv' || echo '  ⚠️  uv manquant'
  command -v gh &>/dev/null && echo '  ✅ gh' || echo '  ⚠️  gh manquant'
  command -v code &>/dev/null && echo '  ✅ VS Code' || echo '  ⚠️  VS Code manquant'
" || true

echo ""
echo "✅ Distrobox '$BOX_NAME' prête à l'emploi !"
echo "👉 Entre dans l'environnement avec : distrobox enter $BOX_NAME"
echo "📝 Log complet : $LOG_FILE"
