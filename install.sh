#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh                              menu interactif
  ./install.sh <environnement> [options]    installe un environnement
  ./install.sh --all [options]              installe tous les environnements
  ./install.sh --list                       liste les environnements (une par ligne)

Options:
  --profile <nom>   profil à installer (voir --list pour les profils disponibles)
  -y, --yes         ne pose aucune question ; NE détruit PAS une box existante
  --recreate        supprime et recrée une box déjà installée (destructif)
  -n, --dry-run     affiche ce qui serait fait, sans rien exécuter
  -h, --help        affiche cette aide

Exemples:
  ./install.sh ubuntu_dev_go --yes
  ./install.sh ubuntu_dev_python --profile data --yes
  ./install.sh fedora_gaming --recreate
EOF
}

# Auto-discovery : tous les dossiers contenant un install.sh, sauf celui-ci.
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

# Profils d'un environnement. Un profil est déclaré de deux façons :
#   - un fichier packages.<profil>.txt   (le profil ajoute des paquets)
#   - une ligne dans profiles.txt        (le profil ne change que le post_install)
# La seconde forme sert aux profils qui n'ajoutent aucun paquet apt, comme les
# CLI cloud de devops, installées depuis leurs propres dépôts.
box_profiles() {
  {
    find "$SCRIPT_DIR/$1" -maxdepth 1 -name 'packages.*.txt' -printf '%f\n' 2>/dev/null \
      | sed -E 's/^packages\.(.*)\.txt$/\1/'
    [ -f "$SCRIPT_DIR/$1/profiles.txt" ] \
      && grep -v '^\s*#' "$SCRIPT_DIR/$1/profiles.txt" | grep -v '^\s*$'
  } 2>/dev/null | sort -u
}

box_exists_in_repo() {
  local b
  for b in "${BOXES[@]}"; do [ "$b" = "$1" ] && return 0; done
  return 1
}

### --- Arguments -----------------------------------------------------------
TARGET=""
PROFILE=""
DO_ALL=0
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)    usage; exit 0 ;;
    --list)
      for b in "${BOXES[@]}"; do
        mapfile -t p < <(box_profiles "$b")
        if [ ${#p[@]} -gt 0 ]; then
          printf '%s\tprofils: base %s\n' "$b" "${p[*]}"
        else
          printf '%s\n' "$b"
        fi
      done
      exit 0
      ;;
    --all)        DO_ALL=1; shift ;;
    --profile)    PROFILE="${2:-}"; shift 2 ;;
    --profile=*)  PROFILE="${1#*=}"; shift ;;
    -y|--yes)     export DISTROSCRIPT_ASSUME_YES=1; shift ;;
    --recreate)   export DISTROSCRIPT_RECREATE=1; export DISTROSCRIPT_ASSUME_YES=1; shift ;;
    -n|--dry-run) DRY_RUN=1; shift ;;
    -*)           echo "Option inconnue : $1" >&2; usage >&2; exit 1 ;;
    *)
      if [ -n "$TARGET" ]; then
        echo "Un seul environnement à la fois (reçu : $TARGET puis $1)." >&2
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
if [ "$DO_ALL" -eq 1 ] && [ -n "$PROFILE" ]; then
  echo "--profile n'a pas de sens avec --all." >&2
  exit 1
fi

### --- Pré-requis ----------------------------------------------------------
check_not_root

if ! command -v distrobox >/dev/null 2>&1; then
  echo "distrobox est introuvable." >&2
  exit 1
fi

detect_container_engine
if [ -z "$CONTAINER_ENGINE" ]; then
  echo "Aucun moteur de conteneur compatible (podman ou docker) détecté." >&2
  exit 1
fi

# Pas en dry-run : celui-ci doit être strictement sans effet de bord.
[ "$DRY_RUN" -eq 1 ] || mkdir -p "$HOME/distrobox"

if [ ${#BOXES[@]} -eq 0 ]; then
  echo "Aucun environnement trouvé." >&2
  exit 1
fi

### --- VS Code sur l'hôte --------------------------------------------------
# Ignoré en mode non interactif : installer un paquet sur l'HÔTE est un effet de
# bord que --yes ne doit pas déclencher en silence.
install_vscode_host() {
  command -v code &>/dev/null && { echo "VS Code déjà présent sur l'hôte."; return 0; }

  if assume_yes; then
    echo "VS Code absent de l'hôte : ignoré (mode non interactif)."
    return 0
  fi
  confirm "VS Code n'est pas installé sur l'hôte. Voulez-vous l'installer ?" || return 0

  if command -v dnf &>/dev/null; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    sudo sh -c 'cat > /etc/yum.repos.d/vscode.repo << EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF'
    sudo dnf install -y code
  elif command -v apt-get &>/dev/null; then
    curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://packages.microsoft.com/keys/microsoft.asc \
      | gpg --dearmor > /tmp/microsoft.gpg
    sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
    rm -f /tmp/microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    sudo apt-get update
    sudo apt-get install -y code
  else
    echo "Gestionnaire de paquets non reconnu. Installez VS Code manuellement." >&2
    return 0
  fi
  command -v code &>/dev/null && echo "VS Code installé." || echo "Installation échouée." >&2
}

### --- Lancement -----------------------------------------------------------
run_install() {
  local box="$1" profile="${2:-}"
  local cmd=("$SCRIPT_DIR/$box/install.sh")
  [ -n "$profile" ] && cmd+=(--profile "$profile")

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] ${cmd[*]}"
    [ "${DISTROSCRIPT_ASSUME_YES:-0}" = "1" ] && echo "[dry-run]   DISTROSCRIPT_ASSUME_YES=1"
    [ "${DISTROSCRIPT_RECREATE:-0}" = "1" ]   && echo "[dry-run]   DISTROSCRIPT_RECREATE=1"
    return 0
  fi
  "${cmd[@]}"
}

# --- Mode --all ---
if [ "$DO_ALL" -eq 1 ]; then
  echo "Environnements à installer : ${BOXES[*]}"
  echo ""
  confirm "Installer les ${#BOXES[@]} environnements ? (plusieurs dizaines de Go)" || { echo "Annulé."; exit 0; }
  install_vscode_host
  failed=()
  for box in "${BOXES[@]}"; do
    echo ""
    echo "=== $box ==="
    run_install "$box" || failed+=("$box")
  done
  echo ""
  if [ ${#failed[@]} -eq 0 ]; then
    echo "Tous les environnements sont installés."
  else
    echo "Échecs : ${failed[*]}" >&2
    exit 1
  fi
  exit 0
fi

# --- Mode ciblé (argument fourni) ---
if [ -n "$TARGET" ]; then
  if ! box_exists_in_repo "$TARGET"; then
    echo "Environnement inconnu : $TARGET" >&2
    echo "Disponibles : ${BOXES[*]}" >&2
    exit 1
  fi
  if [ -n "$PROFILE" ] && [ "$PROFILE" != "base" ]; then
    mapfile -t avail < <(box_profiles "$TARGET")
    if ! printf '%s\n' "${avail[@]}" | grep -qx "$PROFILE"; then
      echo "Profil inconnu pour $TARGET : $PROFILE" >&2
      echo "Disponibles : base ${avail[*]}" >&2
      exit 1
    fi
  fi
  install_vscode_host
  run_install "$TARGET" "$PROFILE"
  echo ""
  echo "Terminé. Utilisez 'distrobox enter $TARGET' pour y accéder."
  exit 0
fi

# --- Mode interactif (aucun argument) ---
echo "Prérequis OK"
echo ""
install_vscode_host

echo "Quelle distrobox installer ?"
for i in "${!BOXES[@]}"; do
  printf "%2d) %s\n" "$((i+1))" "${BOXES[$i]}"
done
echo " q) Quitter"
read -rp "> " choix

case "$choix" in
  q|Q) exit 0 ;;
  *)
    if [[ "$choix" =~ ^[0-9]+$ ]] && (( choix >= 1 && choix <= ${#BOXES[@]} )); then
      box="${BOXES[$((choix-1))]}"
      mapfile -t PROFILES < <(box_profiles "$box")
      chosen=""
      if [ ${#PROFILES[@]} -gt 0 ]; then
        echo ""
        echo "Cet environnement propose plusieurs profils :"
        echo "  1) base (par défaut)"
        for i in "${!PROFILES[@]}"; do
          printf "  %d) %s\n" "$((i+2))" "${PROFILES[$i]}"
        done
        read -rp "> " prof_choix
        if [[ "$prof_choix" =~ ^[0-9]+$ ]] && (( prof_choix >= 2 && prof_choix <= ${#PROFILES[@]} + 1 )); then
          chosen="${PROFILES[$((prof_choix-2))]}"
        fi
      fi
      run_install "$box" "$chosen"
    else
      echo "Choix invalide." >&2
      exit 1
    fi
    ;;
esac

echo ""
echo "Terminé. Utilisez 'distrobox enter <nom>' pour y accéder."
