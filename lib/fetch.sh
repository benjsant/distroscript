#!/bin/bash
# Helpers de téléchargement : à sourcer dans les post_install.sh.
#
# À copier dans le HOME_DIR de la box par install.sh, puis dans
# post_install.sh : source ~/fetch.sh

# Options curl communes : retries, timeout, échec sur code HTTP >= 400,
# et suivi des redirections (GitHub renvoie 301 quand un dépôt est renommé).
CURL_OPTS=(--retry 3 --retry-delay 2 --connect-timeout 10 -fsSL)

# Récupère le tag de la dernière release GitHub d'un dépôt.
#
#   github_latest_tag <owner/repo> <version_de_repli>
#
# L'API anonyme est limitée à 60 requêtes/h et par IP. Au-delà, `jq -r .tag_name`
# renvoie "null", l'URL construite devient .../download/null/outil.tar.gz, curl
# échoue et `set -e` tue le post-install au milieu, laissant une box à moitié
# configurée. Ce helper détecte le cas et retombe sur la version épinglée dans
# versions.sh plutôt que de tout faire échouer.
#
# GITHUB_TOKEN est honoré s'il est présent (limite portée à 5000 requêtes/h).
github_latest_tag() {
  local repo="$1" fallback="$2" tag auth=()
  [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

  # `|| true` couvre tout le pipeline : sans lui, un échec de curl sous
  # `set -o pipefail` ferait échouer l'affectation, donc avorter le script.
  tag="$(curl "${CURL_OPTS[@]}" "${auth[@]}" \
           "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
         | jq -r '.tag_name // empty' 2>/dev/null || true)"

  if [ -z "$tag" ] || [ "$tag" = "null" ]; then
    echo "  API GitHub indisponible pour ${repo} : repli sur ${fallback}." >&2
    tag="$fallback"
  fi
  printf '%s' "$tag"
}

# Télécharge un fichier, en vérifiant son SHA-256 si fourni.
#
#   download_file <url> <destination> [sha256]
#
# Un fichier dont la somme ne correspond pas est supprimé : mieux vaut pas de
# binaire du tout qu'un binaire non vérifié laissé sur le disque.
download_file() {
  local url="$1" dest="$2" sha="${3:-}"
  curl "${CURL_OPTS[@]}" "$url" -o "$dest"
  if [ -n "$sha" ]; then
    if ! echo "${sha}  ${dest}" | sha256sum -c --status; then
      echo "Somme SHA-256 invalide pour ${url} : fichier supprimé." >&2
      rm -f "$dest"
      return 1
    fi
  fi
}

# Télécharge un binaire et le rend exécutable.
#
#   download_bin <url> <destination> [sha256]
download_bin() {
  download_file "$1" "$2" "${3:-}" && chmod +x "$2"
}

# Télécharge une archive .tar.gz et en extrait des membres précis.
#
#   download_tar_extract <url> <dossier_destination> <membre> [membre...]
download_tar_extract() {
  local url="$1" dest_dir="$2"
  shift 2
  local tmp_tgz
  tmp_tgz="$(mktemp --suffix=.tgz)"
  if ! download_file "$url" "$tmp_tgz"; then
    rm -f "$tmp_tgz"
    return 1
  fi
  tar -xzf "$tmp_tgz" -C "$dest_dir" "$@"
  rm -f "$tmp_tgz"
}
