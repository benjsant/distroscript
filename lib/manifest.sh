#!/bin/bash
# Génération de manifestes distrobox-assemble (PILOTE — voir assemble/README.md)
#
# Principe : `distrobox assemble` est déclaratif, donc statique. Il ne sait rien
# faire de la détection d'hôte (GID render, délégation cgroups, présence du bus
# D-Bus, toolkit NVIDIA) — or c'est exactement ce que lib/common.sh apporte.
#
# On garde donc chacun sur son terrain :
#
#   bash (common.sh)          détecte l'hôte, pose les questions, logue
#        ↓ génère
#   distrobox.ini             manifeste calculé pour CETTE machine
#        ↓
#   distrobox assemble create crée la box
#
# Un manifeste écrit à la main serait faux dès qu'on change de machine : les GID
# des groupes render/input/audio diffèrent, le bus D-Bus peut être absent, la
# délégation cgroups indisponible.

# ---------------------------------------------------------------------------
# Helpers communs
# ---------------------------------------------------------------------------

# Convertit un packages.txt en lignes additional_packages.
# assemble accepte plusieurs déclarations de la même clé : elles se cumulent.
manifest_packages_line() {
  local file="$1" pkgs
  [ -f "$file" ] || return 0
  pkgs="$(grep -v '^\s*#' "$file" | grep -v '^\s*$' | tr '\n' ' ' | sed 's/ *$//')"
  [ -n "$pkgs" ] && echo "additional_packages=$pkgs"
}

# GID des groupes hôte utiles au passage de périphériques, sous forme de flags
# --group-add. C'est LA valeur qui change d'une machine à l'autre et qui rend
# tout manifeste versionné à la main incorrect.
manifest_group_flags() {
  local grp gid out=""
  for grp in "$@"; do
    gid="$(getent group "$grp" 2>/dev/null | awk -F: '{print $3}')"
    [ -n "$gid" ] && out="$out --group-add=$gid"
  done
  printf '%s' "${out# }"
}

# ---------------------------------------------------------------------------
# Environnements de développement (base Ubuntu)
# ---------------------------------------------------------------------------

# Entrée [base_ubuntu] commune, héritée via `include=base_ubuntu`. C'est ce qui
# supprime la duplication du bloc « utilitaires dev » recopié dans chaque
# packages.txt.
manifest_base_ubuntu() {
  cat <<EOF
[base_ubuntu]
image=${UBUNTU_IMAGE}
additional_packages=bat ripgrep fzf jq htop tree unzip tmux gh rsync lsof strace zsh
additional_packages=build-essential curl git ca-certificates

EOF
}

manifest_entry_ubuntu() {
  local name="$1" home_dir="$2" pkg_file="$3" hook="$4"
  local flags=""

  echo "[$name]"
  echo "include=base_ubuntu"
  echo "home=$home_dir"
  manifest_packages_line "$pkg_file"

  [ -d /dev/dri ] && flags="--device=/dev/dri"
  flags="$flags $(manifest_group_flags render)"

  if has_nvidia_container_toolkit && command -v lspci &>/dev/null \
     && lspci 2>/dev/null | grep -qi 'NVIDIA'; then
    echo "nvidia=true"
  fi

  flags="$(echo "$flags" | sed 's/^ *//;s/ *$//')"
  [ -n "$flags" ] && echo "additional_flags=$flags"
  [ -n "$hook" ] && echo "init_hooks=$hook"
  echo ""
}

# ---------------------------------------------------------------------------
# Environnements de jeu (fedora_gaming, arch_gaming)
# ---------------------------------------------------------------------------
# Ce sont les box aux flags les plus complexes — périphériques, GID de groupes,
# socket audio, bus D-Bus, systemd conditionnel — donc celles où un manifeste
# généré apporte le plus, et celles qu'il serait le plus faux d'écrire à la main.
manifest_entry_gaming() {
  local name="$1" home_dir="$2" pkg_file="$3" hook="$4" image="$5" games_dir="$6"
  local xdg dbus_socket flags=""

  xdg="$(detect_xdg_runtime)"
  dbus_socket="${xdg}/bus"

  echo "[$name]"
  echo "image=$image"
  echo "home=$home_dir"

  # Les paquets restent installés par le post_install, pas par assemble :
  # additional_packages n'offre pas l'équivalent de --skip-unavailable, or un
  # dépôt tiers cassé ne doit pas faire échouer les 60 autres paquets.
  echo "# paquets installés par le post_install (voir assemble/README.md)"

  echo "volume=${games_dir}:${games_dir}"
  echo "volume=${xdg}:${xdg}"
  [ -S /run/dbus/system_bus_socket ] \
    && echo "volume=/run/dbus/system_bus_socket:/run/dbus/system_bus_socket"

  # systemd seulement si la délégation cgroups v2 est disponible : sans elle,
  # on perd gamemode et rien d'autre.
  if can_run_systemd_in_container; then
    echo "init=true"
  else
    echo "# init=true omis : délégation cgroups v2 absente (gamemode indisponible)"
  fi

  # Steam tourne peut-être aussi sur l'hôte : deux Steam dans le même namespace
  # réseau se disputent les mêmes ports.
  [ "$name" = "arch_gaming" ] && echo "unshare_netns=true"

  if has_nvidia_container_toolkit && command -v lspci &>/dev/null \
     && lspci 2>/dev/null | grep -qi 'NVIDIA'; then
    echo "nvidia=true"
  fi

  flags="--device=/dev/dri --device=/dev/snd --device=/dev/input"
  [ -e /dev/uinput ] && flags="$flags --device=/dev/uinput"
  flags="$flags $(manifest_group_flags render input audio video)"
  [ -S "$dbus_socket" ] && flags="$flags --env=DBUS_SESSION_BUS_ADDRESS=unix:path=${dbus_socket}"

  echo "additional_flags=$(echo "$flags" | sed 's/  */ /g;s/^ *//;s/ *$//')"

  echo "exported_apps=steam lutris"
  [ -n "$hook" ] && echo "init_hooks=$hook"
  echo ""
}
