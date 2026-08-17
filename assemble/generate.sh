#!/bin/bash
# PILOTE — génère un distrobox.ini pour un environnement, à partir de la
# détection d'hôte de lib/common.sh.
#
#   ./assemble/generate.sh ubuntu_dev_go            # écrit sur stdout
#   ./assemble/generate.sh ubuntu_dev_go -o box.ini # écrit dans un fichier
#
# Puis :
#   distrobox assemble create --file box.ini
#   distrobox assemble create --file box.ini --dry-run   # inspection
#   distrobox assemble create --file box.ini --replace   # recréation idempotente
#   distrobox assemble rm     --file box.ini
#
# Ce script ne crée rien : il ne fait qu'émettre le manifeste.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$REPO_ROOT/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"
source "$LIB_DIR/manifest.sh"

OUT=""
BOX_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output) OUT="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,17p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    -*) echo "Option inconnue : $1" >&2; exit 1 ;;
    *)  BOX_NAME="$1"; shift ;;
  esac
done

if [ -z "$BOX_NAME" ]; then
  echo "Usage: $0 <nom_environnement> [-o fichier.ini]" >&2
  exit 1
fi

BOX_DIR="$REPO_ROOT/$BOX_NAME"
if [ ! -d "$BOX_DIR" ]; then
  echo "Environnement inconnu : $BOX_NAME" >&2
  exit 1
fi

HOME_DIR="$HOME/distrobox/$BOX_NAME"

# Le post_install a besoin de versions.sh et shell_setup.sh dans le home de la
# box : même contrat que les install.sh actuels, l'init_hook les suppose présents.
HOOK="bash $HOME_DIR/post_install.sh"

generate() {
  cat <<EOF
# Généré par assemble/generate.sh le $(date +%Y-%m-%d) sur $(hostname).
# NE PAS VERSIONNER : contient des valeurs propres à cette machine
# (GID du groupe render, présence de SELinux, support NVIDIA).
# Régénérer sur chaque nouvelle machine.

EOF
  manifest_base_ubuntu
  manifest_box_entry "$BOX_NAME" "$HOME_DIR" "$BOX_DIR/packages.txt" "$HOOK"
}

if [ -n "$OUT" ]; then
  generate > "$OUT"
  echo "Manifeste écrit : $OUT" >&2
else
  generate
fi
