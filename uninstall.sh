#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ "$EUID" -eq 0 ]; then
  echo "Ce script ne doit pas être lancé en tant que root." >&2
  exit 1
fi

# Auto-discovery : tous les dossiers contenant un install.sh, sauf le install.sh racine
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

remove_box() {
  local name="$1"
  if distrobox list | grep -q "$name"; then
    echo "Suppression de $name..."
    distrobox rm "$name" --force
    rm -rf "$HOME/distrobox/$name"
    rm -f "$HOME/distrobox/${name}_install.log"
    echo "$name supprimé."
  else
    echo "$name n'existe pas, ignoré."
    # Nettoie les résidus éventuels (dossier home ou log laissés par une box précédente)
    rm -rf "$HOME/distrobox/$name"
    rm -f "$HOME/distrobox/${name}_install.log"
  fi
}

echo "Quel environnement supprimer ?"
for i in "${!BOXES[@]}"; do
  printf "%2d) %s\n" "$((i+1))" "${BOXES[$i]}"
done
echo " a) Tous"
echo " q) Quitter"
read -rp "> " choix

case "$choix" in
  q|Q)
    exit 0
    ;;
  a|A)
    read -rp "Confirmer la suppression de TOUS les environnements ? (o/N) " confirm
    if [[ ! "$confirm" =~ ^[oO]$ ]]; then
      echo "Annulé."
      exit 0
    fi
    for box in "${BOXES[@]}"; do
      remove_box "$box"
    done
    echo "Tous les environnements supprimés."
    ;;
  *)
    if [[ "$choix" =~ ^[0-9]+$ ]] && (( choix >= 1 && choix <= ${#BOXES[@]} )); then
      remove_box "${BOXES[$((choix-1))]}"
    else
      echo "Choix invalide." >&2
      exit 1
    fi
    ;;
esac
