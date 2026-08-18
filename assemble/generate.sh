#!/bin/bash
# PILOTE — génère un distrobox.ini pour un environnement, à partir de la
# détection d'hôte de lib/common.sh.
#
#   ./assemble/generate.sh ubuntu_dev_go
#   ./assemble/generate.sh fedora_gaming --games-dir /Data/Jeux
#   ./assemble/generate.sh --all -o distrobox.ini
#
# Puis :
#   distrobox assemble create --file distrobox.ini
#   distrobox assemble create --file distrobox.ini --dry-run   # inspection
#   distrobox assemble create --file distrobox.ini --replace   # recréation
#   distrobox assemble rm     --file distrobox.ini
#
# Ce script ne crée rien : il ne fait qu'émettre le manifeste.
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$REPO_ROOT/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"
source "$LIB_DIR/manifest.sh"

usage() {
  cat <<'EOF'
Usage:
  ./assemble/generate.sh <environnement> [options]
  ./assemble/generate.sh --all [options]

Options:
  -o, --output <fichier>   écrit dans un fichier (défaut : stdout)
  --games-dir <chemin>     dossier de jeux des box gaming (défaut : ~/Games)
  --list                   liste les environnements pris en charge
  -h, --help               affiche cette aide
EOF
}

mapfile -t BOXES < <(
  find "$REPO_ROOT" -maxdepth 2 -name install.sh -not -path "$REPO_ROOT/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

OUT=""
DO_ALL=0
BOX_NAME=""
GAMES_DIR="${GAMES_DIR:-$HOME/Games}"

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--output)   OUT="${2:-}"; shift 2 ;;
    --games-dir)   GAMES_DIR="${2:-}"; shift 2 ;;
    --games-dir=*) GAMES_DIR="${1#*=}"; shift ;;
    --all)         DO_ALL=1; shift ;;
    --list)        printf '%s\n' "${BOXES[@]}"; exit 0 ;;
    -h|--help)     usage; exit 0 ;;
    -*)            echo "Option inconnue : $1" >&2; usage >&2; exit 1 ;;
    *)             BOX_NAME="$1"; shift ;;
  esac
done

if [ "$DO_ALL" -eq 0 ] && [ -z "$BOX_NAME" ]; then
  usage >&2
  exit 1
fi

# distrobox joint additional_flags par des espaces et enveloppe init_hooks dans
# des simples quotes : un chemin contenant un espace ou une apostrophe produirait
# un manifeste cassé, en silence. Mieux vaut refuser tout de suite.
case "$GAMES_DIR" in
  *[[:space:]]*|*\'*)
    echo "GAMES_DIR ne doit contenir ni espace ni apostrophe : $GAMES_DIR" >&2
    echo "distrobox assemble ne sait pas les échapper dans un manifeste." >&2
    exit 1
    ;;
esac

# Émet l'entrée correspondant à un environnement, en choisissant la forme selon
# sa base. C'est ce qui manquait au pilote initial, limité aux box Ubuntu.
emit_box() {
  local box="$1"
  local box_dir="$REPO_ROOT/$box"
  local home_dir="$HOME/distrobox/$box"

  [ -d "$box_dir" ] || { echo "Environnement inconnu : $box" >&2; return 1; }

  case "$box" in
    ubuntu_*)
      manifest_entry_ubuntu "$box" "$home_dir" "$box_dir/packages.txt" \
        "bash $home_dir/post_install.sh"
      ;;
    fedora_gaming)
      manifest_entry_gaming "$box" "$home_dir" "$box_dir/packages.txt" \
        "bash $home_dir/post_install.sh $GAMES_DIR" "$FEDORA_IMAGE" "$GAMES_DIR"
      ;;
    arch_gaming)
      manifest_entry_gaming "$box" "$home_dir" "$box_dir/packages.txt" \
        "bash $home_dir/post_install.sh $GAMES_DIR" "$STEAMBOX_IMAGE" "$GAMES_DIR"
      ;;
    *)
      echo "Base non prise en charge pour $box" >&2
      return 1
      ;;
  esac
}

generate() {
  cat <<EOF
# Généré par assemble/generate.sh le $(date +%Y-%m-%d) sur $(hostname).
# NE PAS VERSIONNER : contient des valeurs propres à cette machine (GID des
# groupes render/input/audio, présence du bus D-Bus, délégation cgroups,
# support NVIDIA). Régénérer sur chaque nouvelle machine.

EOF

  local targets=()
  if [ "$DO_ALL" -eq 1 ]; then
    targets=("${BOXES[@]}")
  else
    targets=("$BOX_NAME")
  fi

  # L'entrée [base_ubuntu] n'est émise que si au moins une box Ubuntu la référence.
  local t
  for t in "${targets[@]}"; do
    case "$t" in ubuntu_*) manifest_base_ubuntu; break ;; esac
  done

  for t in "${targets[@]}"; do
    emit_box "$t"
  done
}

if [ -n "$OUT" ]; then
  generate > "$OUT"
  echo "Manifeste écrit : $OUT" >&2
else
  generate
fi
