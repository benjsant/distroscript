#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi

sudo apt-get update && sudo apt-get upgrade -y
apt_install_from ~/packages_common.txt ~/packages.txt

# SDKMAN : gestion multi-versions JDK/Maven/Gradle/Spring
if [ ! -d "$HOME/.sdkman" ]; then
  echo "Installation de SDKMAN..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -s "https://get.sdkman.io?rcupdate=false" | bash
fi

# Mode non interactif AVANT le sourcing (SDKMAN lit ces vars depuis son config)
if [ -f "$HOME/.sdkman/etc/config" ]; then
  sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$HOME/.sdkman/etc/config"
  sed -i 's/^sdkman_selfupdate_feature=.*/sdkman_selfupdate_feature=false/' "$HOME/.sdkman/etc/config"
fi

# shellcheck disable=SC1091
export SDKMAN_DIR="$HOME/.sdkman"
# sdkman-init.sh référence des variables non définies (SDKMAN_CANDIDATES_API) :
# sous `set -u` le sourcing avorte avec "unbound variable". On relâche -u le
# temps du source, c'est la seule façon de charger SDKMAN dans un script strict.
set +u
# shellcheck disable=SC1091
source "$SDKMAN_DIR/bin/sdkman-init.sh"
set -u

# JDK Temurin LTS (21) + 17 pour compat

# JDK_LTS et JDK_PREV_LTS viennent de versions.sh : ces pins avaient
# échappé à la centralisation et étaient restés sur 21/17.
# Toutes les commandes sdk tournent sous `set +u` : les scripts internes de
# SDKMAN référencent des variables non définies ($2 dans sdkman-install.sh) et
# avortent sinon avec "unbound variable".
#
# Pas de pré-vérification par `sdk list | grep` : à froid, `sdk list java` peut
# ne rien renvoyer d'exploitable, ce qui faisait basculer à tort sur un
# `sdk install java` sans version — précisément la forme qui casse sous set -u.
# On tente la version épinglée, et on rapporte si elle est refusée.
install_sdk() {
  local candidate="$1" version="${2:-}"
  set +u
  if [ -n "$version" ]; then
    if ! sdk install "$candidate" "$version" </dev/null; then
      echo "  [!!] $candidate $version indisponible (voir 'sdk list $candidate')." >&2
      set -u
      return 1
    fi
  else
    sdk install "$candidate" </dev/null || {
      echo "  [!!] $candidate indisponible." >&2; set -u; return 1; }
  fi
  set -u
}

install_sdk java "$JDK_LTS"       || true
install_sdk java "$JDK_PREV_LTS"  || true

set +u
sdk default java "$JDK_LTS" </dev/null || true
set -u

install_sdk maven      || true
install_sdk gradle     || true
install_sdk springboot || true

# .bashrc : SDKMAN ajoute son hook automatiquement, mais on garantit
if ! grep -q 'SDKMAN_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
EOF
fi

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
EOF

echo "Installation Java terminée. $(java --version | head -1)"
