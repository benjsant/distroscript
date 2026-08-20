#!/bin/bash
# Socle commun aux install.sh des environnements Ubuntu.
#
# Les dix install.sh étaient identiques à ~90 % : mêmes vérifications, mêmes
# copies de fichiers, même distrobox-create, seuls le nom de la box et le bloc
# de vérification changeaient. Ils se réduisent désormais à une déclaration.
#
# Chaque environnement fournit :
#   post_install.sh   configuration exécutée DANS la box
#   packages.txt      paquets apt propres à l'environnement
#   verify.sh         vérification post-install, exécutée DANS la box
#   packages.<p>.txt  paquets d'un profil (optionnel)
#   profiles.txt      profils sans paquet propre (optionnel)
#
# Usage, dans <env>/install.sh :
#   SCRIPT_DIR="$(dirname "$(realpath "$0")")"
#   source "$SCRIPT_DIR/../lib/box_common.sh"
#   ubuntu_box_install "$@"

ubuntu_box_install() {
  local script_dir lib_dir box_name home_dir log_file profile="base"

  script_dir="$BOX_SCRIPT_DIR"
  lib_dir="$script_dir/.."/lib
  box_name="$(basename "$script_dir")"
  home_dir="$HOME/distrobox/$box_name"
  log_file="$HOME/distrobox/${box_name}_install.log"

  while [ $# -gt 0 ]; do
    case "$1" in
      --profile)   profile="${2:-}"; shift 2 ;;
      --profile=*) profile="${1#*=}"; shift ;;
      -h|--help)
        echo "Usage: $0 [--profile <nom>]"
        echo "Profils disponibles : base $(box_declared_profiles "$script_dir" | tr '\n' ' ')"
        return 0
        ;;
      *) echo "Option inconnue : $1" >&2; return 1 ;;
    esac
  done

  if [ "$profile" != "base" ] && ! box_declared_profiles "$script_dir" | grep -qx "$profile"; then
    echo "Profil inconnu pour $box_name : '$profile'" >&2
    echo "Disponibles : base $(box_declared_profiles "$script_dir" | tr '\n' ' ')" >&2
    return 1
  fi

  check_not_root
  force_utf8_locale
  enable_logging "$log_file"
  print_host_summary
  [ "$profile" != "base" ] && echo "Profil : $profile"
  check_locale_for_ubuntu_box
  check_or_recreate_box "$box_name" "$home_dir"

  mkdir -p "$home_dir"
  cp "$script_dir/post_install.sh" "$home_dir/"
  cp "$script_dir/packages.txt"    "$home_dir/"
  cp "$script_dir/verify.sh"       "$home_dir/"
  cp "$lib_dir/versions.sh"        "$home_dir/"
  cp "$lib_dir/shell_setup.sh"     "$home_dir/"
  cp "$lib_dir/fetch.sh"           "$home_dir/"
  cp "$lib_dir/packages_common.txt" "$home_dir/"
  # Les fichiers de profil ne sont copiés que s'ils existent
  local pf
  for pf in "$script_dir"/packages.*.txt; do
    [ -f "$pf" ] && cp "$pf" "$home_dir/"
  done

  # Mémorise le profil : update.sh le relit pour savoir quoi mettre à jour
  echo "$profile" > "$home_dir/.profile_name"

  EXTRA_FLAGS=""
  detect_nvidia

  echo "Création de la distrobox '$box_name'..."
  distrobox-create \
    --name "$box_name" \
    --image "$UBUNTU_IMAGE" \
    --home "$home_dir" \
    --additional-flags "$EXTRA_FLAGS"

  echo "Lancement du post-install..."
  distrobox enter -T "$box_name" -- bash -c "bash ~/post_install.sh $profile"

  echo "Vérification..."
  distrobox enter -T "$box_name" -- bash -ic "bash ~/verify.sh $profile" 2>/dev/null || true

  echo ""
  echo "Distrobox '$box_name' prête. Log : $log_file"
  [ -n "${BOX_HINT:-}" ] && echo "$BOX_HINT"
  return 0
}

# Profils déclarés par un environnement : fichiers packages.<p>.txt et/ou
# lignes de profiles.txt. Même règle que le install.sh racine.
box_declared_profiles() {
  local dir="$1"
  {
    find "$dir" -maxdepth 1 -name 'packages.*.txt' -printf '%f\n' 2>/dev/null \
      | sed -E 's/^packages\.(.*)\.txt$/\1/'
    [ -f "$dir/profiles.txt" ] \
      && grep -v '^[[:space:]]*#' "$dir/profiles.txt" | grep -v '^[[:space:]]*$'
  } 2>/dev/null | sort -u
}
