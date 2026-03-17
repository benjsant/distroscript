#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root

BOXES=("ubuntu_dev_hugo" "ubuntu_dev_python" "ubuntu_dev_ia" "ubuntu_dev_rust" "ubuntu_dev_n8n")

echo ""
echo "DistroScript — état des environnements"
echo "---------------------------------------"
echo ""

for box in "${BOXES[@]}"; do
  home_dir="$HOME/distrobox/$box"
  if distrobox list 2>/dev/null | grep -q "$box"; then
    home_size="?"
    if [ -d "$home_dir" ]; then
      home_size=$(du -sh "$home_dir" 2>/dev/null | cut -f1)
    fi
    echo "[ok] $box  ($home_size)"
  else
    echo "[--] $box  non installé"
  fi
done

echo ""
echo "GPU hôte"
echo "--------"
if command -v lspci &>/dev/null; then
  if lspci | grep -i 'NVIDIA' &>/dev/null; then
    echo "NVIDIA"
    command -v nvidia-smi &>/dev/null \
      && nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null \
           | sed 's/^/  /' \
      || true
  elif lspci | grep -iE 'AMD|ATI|Radeon' &>/dev/null; then
    echo "AMD/Radeon"
  else
    echo "aucun GPU dédié"
  fi
else
  echo "lspci non disponible" >&2
fi
echo ""
