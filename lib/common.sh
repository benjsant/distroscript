#!/bin/bash
# Fonctions partagées entre tous les scripts

check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    echo "Ce script ne doit pas être exécuté en tant que root." >&2
    exit 1
  fi
}

check_or_recreate_box() {
  local box_name="$1"
  local home_dir="$2"
  if distrobox list | grep -q "$box_name"; then
    read -rp "La distrobox '$box_name' existe déjà. La supprimer et recréer ? (o/N) " confirm
    if [[ "$confirm" =~ ^[oO]$ ]]; then
      distrobox rm "$box_name" --force
      rm -rf "$home_dir"
    else
      echo "Annulé."
      exit 1
    fi
  fi
}

detect_nvidia() {
  EXTRA_FLAGS="--device=/dev/dri"
  if command -v lspci &>/dev/null && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
    echo "GPU NVIDIA détecté — activation du support NVIDIA..."
    EXTRA_FLAGS="$EXTRA_FLAGS --nvidia"
  fi
}

enable_logging() {
  local log_file="$1"
  mkdir -p "$(dirname "$log_file")"
  exec > >(tee "$log_file") 2>&1
  echo "Log : $log_file"
}
