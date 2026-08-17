#!/bin/bash
# Génération de manifestes distrobox-assemble (PILOTE — voir assemble/README.md)
#
# Principe : `distrobox assemble` est déclaratif, donc statique. Il ne sait rien
# faire de la détection d'hôte (GID render, suffixe SELinux, délégation cgroups,
# présence du toolkit NVIDIA) — or c'est exactement ce que lib/common.sh apporte.
#
# On garde donc chacun sur son terrain :
#
#   bash (common.sh)          détecte l'hôte, pose les questions, logue
#        ↓ génère
#   distrobox.ini             manifeste calculé pour CETTE machine
#        ↓
#   distrobox assemble create crée la box
#
# Un manifeste écrit à la main serait faux dès qu'on change de machine : le GID
# du groupe render diffère, SELinux peut être absent (donc pas de suffixe :z).

# Émet sur stdout le bloc [base_ubuntu] commun à tous les environnements Ubuntu.
# Les autres entrées l'héritent via `include=base_ubuntu`, ce qui supprime la
# duplication du bloc « utilitaires dev » recopié dans chaque packages.txt.
manifest_base_ubuntu() {
  cat <<EOF
[base_ubuntu]
image=${UBUNTU_IMAGE}
additional_packages=bat ripgrep fzf jq htop tree unzip tmux gh rsync lsof strace zsh
additional_packages=build-essential curl git ca-certificates

EOF
}

# Convertit un packages.txt en une ligne additional_packages.
# Les commentaires et lignes vides sont retirés ; assemble accepte plusieurs
# déclarations de la même clé, elles se cumulent.
manifest_packages_line() {
  local file="$1" pkgs
  [ -f "$file" ] || return 0
  pkgs="$(grep -v '^\s*#' "$file" | grep -v '^\s*$' | tr '\n' ' ' | sed 's/ *$//')"
  [ -n "$pkgs" ] && echo "additional_packages=$pkgs"
}

# Émet une entrée d'environnement.
#   $1 nom de la box   $2 home dir   $3 packages.txt   $4 commande init_hooks
# Les flags dépendants de l'hôte sont calculés ici, à la génération.
manifest_box_entry() {
  local name="$1" home_dir="$2" pkg_file="$3" hook="$4"
  local flags=()

  echo "[$name]"
  echo "include=base_ubuntu"
  echo "home=$home_dir"
  manifest_packages_line "$pkg_file"

  # --- Ce qui ne peut PAS être écrit en dur dans un manifeste versionné ---
  [ -d /dev/dri ] && flags+=(--device=/dev/dri)

  local render_gid
  render_gid="$(detect_render_gid)"
  [ -n "$render_gid" ] && flags+=(--group-add="$render_gid")

  if has_nvidia_container_toolkit && command -v lspci &>/dev/null \
     && lspci 2>/dev/null | grep -qi 'NVIDIA'; then
    echo "nvidia=true"
  fi

  [ ${#flags[@]} -gt 0 ] && echo "additional_flags=${flags[*]}"

  [ -n "$hook" ] && echo "init_hooks=$hook"
  echo ""
}
