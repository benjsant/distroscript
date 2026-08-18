#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root

usage() {
  cat <<'EOF'
Usage:
  ./uninstall.sh                     menu interactif
  ./uninstall.sh <environnement>     supprime un environnement
  ./uninstall.sh --all               supprime tous les environnements
  ./uninstall.sh --list              liste les environnements

Options:
  -y, --yes         ne demande aucune confirmation (destructif)
  -n, --dry-run     affiche ce qui serait supprimé, sans rien supprimer
  -h, --help        affiche cette aide

La suppression retire le conteneur, son dossier home (~/distrobox/<nom>) et son
log d'installation. Un éventuel dossier de jeux (--games-dir) n'est PAS touché.
EOF
}

# Auto-discovery : tous les dossiers contenant un install.sh, sauf le install.sh racine
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

TARGET=""
DO_ALL=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    --list)       printf '%s\n' "${BOXES[@]}"; exit 0 ;;
    --all)        DO_ALL=1; shift ;;
    -y|--yes)     export DISTROSCRIPT_ASSUME_YES=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -*)           echo "Option inconnue : $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -n "$TARGET" ]; then
        echo "Un seul environnement à la fois." >&2
        exit 1
      fi
      TARGET="$1"; shift
      ;;
  esac
done

if [ "$DO_ALL" -eq 1 ] && [ -n "$TARGET" ]; then
  echo "--all et un nom d'environnement sont exclusifs." >&2
  exit 1
fi

remove_box() {
  local name="$1"
  local home_dir="$HOME/distrobox/$name"
  local log_file="$HOME/distrobox/${name}_install.log"

  if [ "$DRY_RUN" -eq 1 ]; then
    box_exists "$name" && echo "[dry-run] distrobox rm $name --force" \
                       || echo "[dry-run] $name : conteneur absent"
    [ -d "$home_dir" ] && echo "[dry-run] rm -rf $home_dir ($(du -sh "$home_dir" 2>/dev/null | cut -f1))"
    [ -f "$log_file" ] && echo "[dry-run] rm -f $log_file"
    return 0
  fi

  if box_exists "$name"; then
    echo "Suppression de $name..."
    distrobox rm "$name" --force
    echo "$name supprimé."
  else
    echo "$name n'existe pas, nettoyage des résidus éventuels."
  fi
  # Dans les deux cas : home et log peuvent subsister d'une installation passée.
  rm -rf "$home_dir"
  rm -f "$log_file"
}

if [ "$DO_ALL" -eq 1 ]; then
  if ! confirm "Confirmer la suppression de TOUS les environnements ?"; then
    echo "Annulé."
    exit 0
  fi
  for box in "${BOXES[@]}"; do
    remove_box "$box"
  done
  echo "Tous les environnements supprimés."
  exit 0
fi

if [ -n "$TARGET" ]; then
  found=0
  for b in "${BOXES[@]}"; do [ "$b" = "$TARGET" ] && found=1; done
  if [ "$found" -eq 0 ]; then
    echo "Environnement inconnu : $TARGET" >&2
    echo "Disponibles : ${BOXES[*]}" >&2
    exit 1
  fi
  confirm "Supprimer $TARGET ?" || { echo "Annulé."; exit 0; }
  remove_box "$TARGET"
  exit 0
fi

echo "Quel environnement supprimer ?"
for i in "${!BOXES[@]}"; do
  printf "%2d) %s\n" "$((i+1))" "${BOXES[$i]}"
done
echo " a) Tous"
echo " q) Quitter"
read -rp "> " choix

case "$choix" in
  q|Q) exit 0 ;;
  a|A)
    confirm "Confirmer la suppression de TOUS les environnements ?" || { echo "Annulé."; exit 0; }
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
