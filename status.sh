#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root

# Auto-discovery : tous les dossiers contenant un install.sh, sauf le install.sh racine
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

echo ""
echo "DistroScript — état des environnements"
echo "---------------------------------------"
echo ""

for box in "${BOXES[@]}"; do
  home_dir="$HOME/distrobox/$box"
  if box_exists "$box"; then
    home_size="?"
    if [ -d "$home_dir" ]; then
      home_size="$(du -sh "$home_dir" 2>/dev/null | cut -f1)"
    fi
    printf "  [ok] %-30s (%s)\n" "$box" "$home_size"
  else
    printf "  [--] %-30s non installé\n" "$box"
  fi
done

echo ""
echo "Environnement hôte"
echo "------------------"
print_host_summary

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
    if rocm_path="$(detect_rocm_path 2>/dev/null)"; then
      echo "  ROCm trouvé : $rocm_path"
    fi
  else
    echo "aucun GPU dédié"
  fi
else
  echo "lspci non disponible" >&2
fi
echo ""
