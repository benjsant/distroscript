#!/bin/bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
  echo "Ce script ne doit pas être lancé en tant que root." >&2
  exit 1
fi

BOXES=("ubuntu_dev_hugo" "ubuntu_dev_python" "ubuntu_dev_ia" "ubuntu_dev_rust" "ubuntu_dev_n8n")

remove_box() {
  local name="$1"
  if distrobox list | grep -q "$name"; then
    echo "Suppression de $name..."
    distrobox rm "$name" --force
    rm -rf "$HOME/distrobox/$name"
    echo "$name supprimé."
  else
    echo "$name n'existe pas, ignoré."
  fi
}

echo "Quel environnement supprimer ?"
for i in "${!BOXES[@]}"; do
  echo "$((i+1))) ${BOXES[$i]}"
done
echo "a) Tous"
echo "q) Quitter"
read -rp "> " choix

case "$choix" in
  1) remove_box "${BOXES[0]}" ;;
  2) remove_box "${BOXES[1]}" ;;
  3) remove_box "${BOXES[2]}" ;;
  4) remove_box "${BOXES[3]}" ;;
  5) remove_box "${BOXES[4]}" ;;
  a|A)
    for box in "${BOXES[@]}"; do
      remove_box "$box"
    done
    echo "Tous les environnements supprimés."
    ;;
  q|Q)
    exit 0
    ;;
  *)
    echo "Choix invalide." >&2
    exit 1
    ;;
esac
