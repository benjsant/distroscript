#!/bin/bash
# Fonctions partagées entre tous les scripts d'installation

check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    echo "❌ Ce script ne doit pas être exécuté en tant que root."
    exit 1
  fi
}

check_or_recreate_box() {
  local box_name="$1"
  local home_dir="$2"
  if distrobox list | grep -q "$box_name"; then
    echo "⚠️ Une Distrobox nommée '$box_name' existe déjà."
    read -rp "🔁 Voulez-vous la supprimer et la recréer ? (o/N) " confirm
    if [[ "$confirm" =~ ^[oO]$ ]]; then
      echo "🗑️ Suppression de l'ancienne Distrobox..."
      distrobox rm "$box_name" --force
      rm -rf "$home_dir"
    else
      echo "❌ Annulation."
      exit 1
    fi
  fi
}

detect_nvidia() {
  EXTRA_FLAGS="--device=/dev/dri"
  if command -v lspci &>/dev/null && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
    echo "🟢 GPU NVIDIA détecté — activation du support NVIDIA..."
    EXTRA_FLAGS="$EXTRA_FLAGS --nvidia"
  else
    echo "ℹ️ Pas de GPU NVIDIA détecté — mode standard."
  fi
}

enable_logging() {
  local log_file="$1"
  mkdir -p "$(dirname "$log_file")"
  exec > >(tee "$log_file") 2>&1
  echo "📝 Log sauvegardé dans : $log_file"
}
