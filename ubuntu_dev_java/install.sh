#!/bin/bash
set -euo pipefail

BOX_SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$BOX_SCRIPT_DIR/../lib/common.sh"
source "$BOX_SCRIPT_DIR/../lib/versions.sh"
source "$BOX_SCRIPT_DIR/../lib/box_common.sh"

# Consommé par ubuntu_box_install (lib/box_common.sh).
# shellcheck disable=SC2034
BOX_HINT="Astuce : 'sdk list java' pour voir les JDK installables, 'sdk install java X.Y.Z-tem' pour Temurin."
ubuntu_box_install "$@"
