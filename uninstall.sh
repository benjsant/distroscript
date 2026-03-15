#!/bin/bash
set -euo pipefail

### ❌ Vérification root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Ce script ne doit pas être lancé en tant que root."
  exit 1
fi

BOXES=("ubuntu_dev_hugo" "ubuntu_dev_python" "ubuntu_dev_ia")

remove_box() {
  local name="$1"
  if distrobox list | grep -q "$name"; then
    echo "🗑️ Suppression de $name..."
    distrobox rm "$name" --force
    rm -rf "$HOME/distrobox/$name"
    echo "✅ $name supprimé."
  else
    echo "ℹ️ $name n'existe pas, rien à faire."
  fi
}

echo "🗑️ Quel environnement souhaitez-vous supprimer ?"
for i in "${!BOXES[@]}"; do
  echo "$((i+1))) ${BOXES[$i]}"
done
echo "a) Tous"
echo "q) Quitter"
read -rp "👉 Votre choix : " choix

case "$choix" in
  1) remove_box "${BOXES[0]}" ;;
  2) remove_box "${BOXES[1]}" ;;
  3) remove_box "${BOXES[2]}" ;;
  a|A)
    for box in "${BOXES[@]}"; do
      remove_box "$box"
    done
    echo ""
    echo "✅ Tous les environnements ont été supprimés."
    ;;
  q|Q)
    echo "👋 Sortie."
    exit 0
    ;;
  *)
    echo "❌ Choix invalide."
    exit 1
    ;;
esac
