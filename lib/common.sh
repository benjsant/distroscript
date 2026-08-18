#!/bin/bash
# Fonctions partagées entre tous les scripts

# ---------------------------------------------------------------------------
# Mode non interactif
# ---------------------------------------------------------------------------
# Piloté par deux variables d'environnement, héritées automatiquement par les
# install.sh d'environnement lancés depuis le install.sh racine :
#
#   DISTROSCRIPT_ASSUME_YES=1  répond "oui" aux questions NON destructives
#   DISTROSCRIPT_RECREATE=1    autorise en plus la destruction d'une box existante
#
# La distinction est volontaire : --yes ne doit jamais détruire une box que
# l'utilisateur n'a pas explicitement demandé à recréer.

assume_yes() { [ "${DISTROSCRIPT_ASSUME_YES:-0}" = "1" ]; }
allow_recreate() { [ "${DISTROSCRIPT_RECREATE:-0}" = "1" ]; }

# Pose une question oui/non. En mode non interactif, répond "oui" sans demander.
#   confirm "<question>" [defaut_oui]
confirm() {
  local question="$1" default="${2:-non}" answer
  if assume_yes; then
    echo "$question [auto: oui]"
    return 0
  fi
  if [ "$default" = "oui" ]; then
    read -rp "$question [O/n] " answer
    [[ ! "$answer" =~ ^[nN]$ ]]
  else
    read -rp "$question [o/N] " answer
    [[ "$answer" =~ ^[oOyY]$ ]]
  fi
}

check_not_root() {
  if [ "$EUID" -eq 0 ]; then
    echo "Ce script ne doit pas être exécuté en tant que root." >&2
    exit 1
  fi
}

# distrobox-init plante si LANG est sous forme non canonique (ex: "fr_FR.utf8"
# au lieu de "fr_FR.UTF-8") car update-locale refuse cette forme. On neutralise
# en forçant C.UTF-8 pour les appels à distrobox-create et distrobox enter.
force_utf8_locale() {
  export LANG=C.UTF-8
  export LC_ALL=C.UTF-8
}

# True si /etc/locale.conf contient au moins une entrée ".utf8" non canonique
# (forme rejetée par update-locale d'Ubuntu).
locale_conf_is_non_canonical() {
  [ -r /etc/locale.conf ] || return 1
  grep -Eiq '^[A-Z_]+=.*\.(utf8|UTF8)([^A-Za-z0-9_-]|$)' /etc/locale.conf
}

# À appeler dans les install.sh des boxes Ubuntu : détecte un locale.conf hôte
# non canonique et propose de lancer fix_locale.sh tout de suite — sinon la
# première entrée dans la box plantera avec "Installing basic packages... Error".
# Le helper ne fait RIEN si tout est propre.
check_locale_for_ubuntu_box() {
  if ! locale_conf_is_non_canonical; then
    return 0
  fi

  # Localise fix_locale.sh par rapport au common.sh (donc indépendant du caller)
  local repo_root fix_script
  repo_root="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."
  fix_script="${repo_root}/fix_locale.sh"

  echo ""
  echo "⚠ /etc/locale.conf contient des entrées non canoniques (.utf8 au lieu de .UTF-8)."
  echo "  C'est la cause connue du bug 'Installing basic packages... Error: An error occurred'"
  echo "  qui apparaît au premier 'distrobox enter' sur les images Ubuntu."
  echo ""

  if [ ! -x "$fix_script" ]; then
    echo "  Script fix_locale.sh introuvable à $fix_script" >&2
    echo "  Corrige la locale manuellement puis relance cet install." >&2
    exit 1
  fi

  if ! confirm "Lancer fix_locale.sh maintenant ?" oui; then
    echo "⚠ Tu continues sans appliquer le fix — la création de la box risque d'échouer."
    return 0
  fi

  "$fix_script" --apply
  echo ""
  echo "ℹ /etc/locale.conf a été réécrit. distrobox-init lira cette nouvelle"
  echo "  version pour la box que tu vas créer (pas besoin de relogger pour ça)."
  echo "  Une déconnexion/reconnexion reste nécessaire pour que TON shell hôte"
  echo "  prenne la nouvelle locale."
  echo ""
}

# True si une distrobox dont le nom est EXACTEMENT $1 existe.
# (À utiliser au lieu de "distrobox list | grep -q "$name"" qui matche les
# préfixes : "ubuntu_dev_go" matche aussi "ubuntu_dev_golang", "godot", etc.
# Ni grep -qw ne suffit car 'o' et 'l' sont tous deux des word-chars donc
# pas de word-boundary entre eux.)
box_exists() {
  local name="$1"
  distrobox list --no-color 2>/dev/null | awk -F'|' -v n="$name" '
    NR == 1 { next }
    { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 == n) found = 1 }
    END { exit !found }
  '
}

check_or_recreate_box() {
  local box_name="$1"
  local home_dir="$2"
  box_exists "$box_name" || return 0

  # Destruction : jamais implicite. --yes ne suffit pas, il faut --recreate.
  if allow_recreate; then
    echo "La distrobox '$box_name' existe déjà — suppression (--recreate)."
  elif assume_yes; then
    echo "La distrobox '$box_name' existe déjà." >&2
    echo "Relancez avec --recreate pour la supprimer et la recréer." >&2
    exit 1
  elif ! confirm "La distrobox '$box_name' existe déjà. La supprimer et recréer ?"; then
    echo "Annulé."
    exit 1
  fi

  distrobox rm "$box_name" --force
  rm -rf "$home_dir"
}

# Détecte la distribution hôte : "fedora" (inclut Nobara/Bazzite), "debian" (inclut Mint/Ubuntu), ou "other"
#
# /etc/os-release est lu dans un SOUS-SHELL : le sourcer directement définirait
# ID, NAME, VERSION, PRETTY_NAME… dans le shell appelant et écraserait
# silencieusement les variables de même nom de n'importe quel script.
# Les valeurs utiles sont réexportées explicitement, préfixées HOST_.
detect_host_distro() {
  HOST_DISTRO="other"
  HOST_ID_LIKE=""
  HOST_PRETTY_NAME=""
  if [ -r /etc/os-release ]; then
    local raw
    # shellcheck disable=SC1091
    raw="$( . /etc/os-release 2>/dev/null; printf '%s\n%s\n%s' \
              "${ID_LIKE:-} ${ID:-}" "${PRETTY_NAME:-}" "${ID:-}" )"
    HOST_ID_LIKE="$(printf '%s' "$raw" | sed -n '1p')"
    HOST_PRETTY_NAME="$(printf '%s' "$raw" | sed -n '2p')"
    case "$HOST_ID_LIKE" in
      *fedora*|*rhel*) HOST_DISTRO="fedora" ;;
      *debian*|*ubuntu*) HOST_DISTRO="debian" ;;
    esac
  fi
  export HOST_DISTRO HOST_ID_LIKE HOST_PRETTY_NAME
}

# Détecte le moteur de conteneurs préféré
detect_container_engine() {
  if command -v podman &>/dev/null; then
    CONTAINER_ENGINE="podman"
  elif command -v docker &>/dev/null; then
    CONTAINER_ENGINE="docker"
  else
    CONTAINER_ENGINE=""
  fi
  export CONTAINER_ENGINE
}

# True si SELinux est actif et en mode enforcing/permissive
is_selinux_enforced() {
  if command -v getenforce &>/dev/null; then
    case "$(getenforce 2>/dev/null)" in
      Enforcing|Permissive) return 0 ;;
    esac
  fi
  [ -f /sys/fs/selinux/enforce ] && return 0
  return 1
}

# Détecte le module de sécurité (LSM) réellement actif sur l'hôte.
# Nobara, par exemple, utilise AppArmor et n'a pas SELinux du tout — dire
# seulement "SELinux : inactif" est exact mais trompeur.
detect_lsm() {
  local lsms=""
  [ -r /sys/kernel/security/lsm ] && lsms="$(cat /sys/kernel/security/lsm)"
  case ",$lsms," in
    *,selinux,*) echo "selinux" ;;
    *,apparmor,*) echo "apparmor" ;;
    *) echo "${lsms:-inconnu}" ;;
  esac
}

# Suffixe SELinux pour les --volume — ":z" si SELinux actif, vide sinon.
#
# ATTENTION : ne PAS utiliser pour les volumes des boxes distrobox.
# distrobox-create passe --security-opt label=disable de façon inconditionnelle,
# donc le conteneur n'est jamais confiné par SELinux et ":z" est inutile. Pire,
# ":z" déclenche un réétiquetage RÉCURSIF du volume : appliqué à une
# bibliothèque de jeux ou à /usr/lib64/rocm, c'est très long et ça modifie les
# étiquettes côté hôte. Conservé pour un éventuel usage hors distrobox.
selinux_volume_suffix() {
  if is_selinux_enforced; then
    echo ":z"
  else
    echo ""
  fi
}

# True si cgroups v2 unifié
is_cgroups_v2() {
  [ -f /sys/fs/cgroup/cgroup.controllers ]
}

# True si la délégation cgroups est active pour l'utilisateur courant
has_cgroup_delegation() {
  is_cgroups_v2 || return 1
  command -v loginctl &>/dev/null || return 1
  loginctl show-user "$USER" 2>/dev/null | grep -q '^Delegate=yes' || return 1
  return 0
}

# Vérifie si systemd-in-container est faisable
can_run_systemd_in_container() {
  has_cgroup_delegation
}

# True si nvidia-container-toolkit (ou équivalent) est installé sur l'hôte
has_nvidia_container_toolkit() {
  command -v nvidia-ctk &>/dev/null || command -v nvidia-container-runtime &>/dev/null
}

# Détecte le chemin du runtime XDG de l'utilisateur (plus robuste que /run/user/$UID)
detect_xdg_runtime() {
  if command -v loginctl &>/dev/null; then
    local rp
    rp="$(loginctl show-user "$USER" -p RuntimePath --value 2>/dev/null)"
    if [ -n "$rp" ] && [ -d "$rp" ]; then
      echo "$rp"
      return
    fi
  fi
  echo "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
}

# GID du groupe render sur l'hôte (utile pour --device=/dev/dri sur hôtes Fedora/Ubuntu mixtes)
detect_render_gid() {
  if getent group render >/dev/null 2>&1; then
    getent group render | awk -F: '{print $3}'
  else
    echo ""
  fi
}

# Détection GPU NVIDIA + activation du flag --nvidia uniquement si le toolkit est présent
detect_nvidia() {
  EXTRA_FLAGS="${EXTRA_FLAGS:-}"

  # /dev/dri est presque toujours présent ; on l'expose pour le rendu vidéo / VAAPI
  if [ -d /dev/dri ]; then
    EXTRA_FLAGS="$EXTRA_FLAGS --device=/dev/dri"
  fi

  if command -v lspci &>/dev/null && lspci | grep -i 'NVIDIA' >/dev/null 2>&1; then
    if has_nvidia_container_toolkit; then
      echo "GPU NVIDIA détecté + nvidia-container-toolkit présent — activation du support NVIDIA."
      EXTRA_FLAGS="$EXTRA_FLAGS --nvidia"
    else
      echo "GPU NVIDIA détecté mais nvidia-container-toolkit absent — flag --nvidia désactivé." >&2
      echo "  Installez-le pour activer CUDA dans la box :" >&2
      echo "    Fedora/Nobara: sudo dnf install -y nvidia-container-toolkit" >&2
      echo "    Debian/Mint  : voir https://docs.nvidia.com/datacenter/cloud-native/" >&2
    fi
  fi

}

# Cherche un dossier ROCm dans les emplacements connus (Fedora vs Ubuntu)
detect_rocm_path() {
  local candidate
  for candidate in /opt/rocm* /usr/lib64/rocm* /usr/lib/rocm* /usr/share/rocm; do
    for dir in $candidate; do
      [ -d "$dir" ] && { echo "$dir"; return 0; }
    done
  done
  return 1
}

enable_logging() {
  local log_file="$1"
  mkdir -p "$(dirname "$log_file")"
  exec > >(tee "$log_file") 2>&1
  echo "Log : $log_file"
}

# Affiche un résumé de l'environnement hôte au début de l'install
print_host_summary() {
  detect_host_distro
  detect_container_engine
  echo "Hôte : ${HOST_PRETTY_NAME:-inconnu} (catégorie: $HOST_DISTRO)"
  echo "Moteur : ${CONTAINER_ENGINE:-aucun}"
  echo "LSM : $(detect_lsm)"
  echo "SELinux : $(is_selinux_enforced && echo "actif" || echo "inactif")"
  echo "cgroups v2 délégué : $(has_cgroup_delegation && echo "oui" || echo "non")"
  echo "nvidia-container-toolkit : $(has_nvidia_container_toolkit && echo "présent" || echo "absent")"
}
