#!/bin/bash
set -euo pipefail

BOX_SCRIPT_DIR="$(dirname "$(realpath "$0")")"

source "$BOX_SCRIPT_DIR/../lib/common.sh"
source "$BOX_SCRIPT_DIR/../lib/versions.sh"
source "$BOX_SCRIPT_DIR/../lib/box_common.sh"

ubuntu_box_install "$@"
