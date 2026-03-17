#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root

BOXES=("ubuntu_dev_hugo" "ubuntu_dev_python" "ubuntu_dev_ia" "ubuntu_dev_rust" "ubuntu_dev_n8n")

update_apt() {
  local name="$1"
  distrobox enter "$name" -- bash -c "sudo apt update && sudo apt upgrade -y"
}

update_hugo() {
  distrobox enter "ubuntu_dev_hugo" -- bash -c "
    eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" 2>/dev/null || true
    brew upgrade 2>/dev/null || true
  "
}

update_python_tools() {
  local name="$1"
  distrobox enter "$name" -- bash -c "
    [ -d \$HOME/.pyenv ] && git -C \$HOME/.pyenv pull || true
    [ -f \$HOME/.local/bin/uv ] && \$HOME/.local/bin/uv self update || true
  "
}

update_nvm() {
  local name="$1"
  distrobox enter "$name" -- bash -c "
    export NVM_DIR=\"\$HOME/.nvm\"
    [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
    command -v nvm &>/dev/null && nvm install --lts --reinstall-packages-from=default 2>/dev/null || true
  "
}

update_rust() {
  distrobox enter "ubuntu_dev_rust" -- bash -c "
    [ -f \$HOME/.cargo/env ] && . \$HOME/.cargo/env
    rustup update 2>/dev/null || true
  "
}

update_ollama() {
  distrobox enter "ubuntu_dev_ia" -- bash -c "
    if command -v ollama &>/dev/null; then
      curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || true
      ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}' | while read -r model; do
        [ -z \"\$model\" ] && continue
        ollama pull \"\$model\" || true
      done
    fi
  "
}

do_update() {
  local name="$1"
  if ! distrobox list | grep -q "$name"; then
    echo "$name : non installé, ignoré."
    return
  fi
  echo ""
  echo "--- $name ---"
  update_apt "$name"
  case "$name" in
    ubuntu_dev_hugo)   update_hugo; update_nvm "$name" ;;
    ubuntu_dev_python) update_python_tools "$name"; update_nvm "$name" ;;
    ubuntu_dev_ia)     update_python_tools "$name"; update_ollama ;;
    ubuntu_dev_rust)   update_rust ;;
    ubuntu_dev_n8n)    update_nvm "ubuntu_dev_n8n" ;;
  esac
  echo "$name : OK"
}

echo "Quel environnement mettre à jour ?"
for i in "${!BOXES[@]}"; do
  echo "$((i+1))) ${BOXES[$i]}"
done
echo "a) Tous"
echo "q) Quitter"
read -rp "> " choix

case "$choix" in
  1) do_update "${BOXES[0]}" ;;
  2) do_update "${BOXES[1]}" ;;
  3) do_update "${BOXES[2]}" ;;
  4) do_update "${BOXES[3]}" ;;
  5) do_update "${BOXES[4]}" ;;
  a|A)
    for box in "${BOXES[@]}"; do
      do_update "$box"
    done
    echo ""
    echo "Tous les environnements sont à jour."
    ;;
  q|Q)
    exit 0
    ;;
  *)
    echo "Choix invalide." >&2
    exit 1
    ;;
esac
