#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root
force_utf8_locale

# Auto-discovery : tous les dossiers contenant un install.sh, sauf le install.sh racine
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

# ---------- Helpers de mise à jour ----------

# apt upgrade pour les boxes Ubuntu ; dnf upgrade pour fedora_gaming
update_packages() {
  local name="$1"
  if [[ "$name" == ubuntu_* ]]; then
    distrobox enter "$name" -- bash -c 'sudo apt update && sudo apt upgrade -y'
  elif [[ "$name" == fedora_* ]]; then
    distrobox enter "$name" -- bash -c 'sudo dnf upgrade -y'
  fi
}

update_hugo() {
  distrobox enter "ubuntu_dev_hugo" -- bash -c '
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
    brew update && brew upgrade 2>/dev/null || true
  '
}

update_pyenv_uv() {
  local name="$1"
  distrobox enter "$name" -- bash -c '
    [ -d "$HOME/.pyenv" ] && git -C "$HOME/.pyenv" pull --ff-only || true
    [ -f "$HOME/.local/bin/uv" ] && "$HOME/.local/bin/uv" self update || true
  '
}

update_nvm() {
  local name="$1"
  distrobox enter "$name" -- bash -c '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    command -v nvm &>/dev/null && nvm install --lts --reinstall-packages-from=default 2>/dev/null || true
  '
}

update_rust() {
  distrobox enter "ubuntu_dev_rust" -- bash -c '
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
    rustup update 2>/dev/null || true
  '
}

update_ollama() {
  distrobox enter "ubuntu_dev_ia" -- bash -c '
    if command -v ollama &>/dev/null; then
      curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || true
      ollama list 2>/dev/null | tail -n +2 | awk "{print \$1}" | while read -r model; do
        [ -z "$model" ] && continue
        ollama pull "$model" || true
      done
    fi
  '
}

update_go_tools() {
  distrobox enter "ubuntu_dev_go" -- bash -ic '
    go install golang.org/x/tools/gopls@latest 2>/dev/null || true
    go install github.com/go-delve/delve/cmd/dlv@latest 2>/dev/null || true
    go install github.com/air-verse/air@latest 2>/dev/null || true
    go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || true
    go install golang.org/x/tools/cmd/goimports@latest 2>/dev/null || true
  ' 2>/dev/null || true
}

update_sdkman() {
  distrobox enter "ubuntu_dev_java" -- bash -c '
    export SDKMAN_DIR="$HOME/.sdkman"
    [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdk selfupdate force </dev/null 2>/dev/null || true
  '
}

update_dotnet_tools() {
  distrobox enter "ubuntu_dev_dotnet" -- bash -c '
    export PATH="$HOME/.dotnet/tools:$PATH"
    dotnet tool update --global dotnet-ef 2>/dev/null || true
    dotnet tool update --global dotnet-format 2>/dev/null || true
    dotnet tool update --global dotnet-outdated-tool 2>/dev/null || true
  '
}

update_flutter() {
  distrobox enter "ubuntu_dev_flutter" -- bash -ic '
    flutter upgrade 2>/dev/null || true
    flutter precache --linux --web --no-android --no-ios --no-macos --no-windows --no-fuchsia 2>/dev/null || true
  ' 2>/dev/null || true
}

update_composer() {
  distrobox enter "ubuntu_dev_php" -- bash -c '
    export PATH="$HOME/.local/bin:$HOME/.config/composer/vendor/bin:$PATH"
    sudo "$HOME/.local/bin/composer" self-update 2>/dev/null || composer self-update 2>/dev/null || true
    composer global update 2>/dev/null || true
  '
}

update_uv_tools() {
  local name="$1"
  distrobox enter "$name" -- bash -c '
    export PATH="$HOME/.local/bin:$PATH"
    command -v uv &>/dev/null && uv self update 2>/dev/null || true
    command -v uv &>/dev/null && uv tool upgrade --all 2>/dev/null || true
  '
}

update_npm_global() {
  local name="$1"
  distrobox enter "$name" -- bash -c '
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    command -v npm &>/dev/null && npm update -g 2>/dev/null || true
  '
}

# ---------- Dispatch ----------

do_update() {
  local name="$1"
  if ! distrobox list | grep -q "$name"; then
    echo "$name : non installé, ignoré."
    return
  fi
  echo ""
  echo "--- $name ---"
  update_packages "$name"
  case "$name" in
    ubuntu_dev_hugo)            update_hugo;             update_nvm "$name" ;;
    ubuntu_dev_python)          update_pyenv_uv "$name"; update_nvm "$name" ;;
    ubuntu_dev_ia)              update_pyenv_uv "$name"; update_ollama ;;
    ubuntu_dev_rust)            update_rust ;;
    ubuntu_dev_n8n)             update_nvm "$name";      update_npm_global "$name" ;;
    ubuntu_dev_go)              update_go_tools ;;
    ubuntu_dev_devops)          : ;;  # apt suffit
    ubuntu_dev_dotnet)          update_dotnet_tools ;;
    ubuntu_dev_writing)         update_nvm "$name";      update_npm_global "$name" ;;
    ubuntu_dev_data)            update_uv_tools "$name" ;;
    ubuntu_dev_php)             update_composer;         update_nvm "$name" ;;
    ubuntu_dev_java)            update_sdkman ;;
    ubuntu_dev_video)           : ;;  # apt suffit, whisper.cpp non auto-update
    ubuntu_dev_security_audit)  update_uv_tools "$name" ;;
    ubuntu_dev_flutter)         update_flutter ;;
    fedora_gaming)              : ;;  # dnf suffit
  esac
  echo "$name : OK"
}

# ---------- Menu ----------

echo "Quel environnement mettre à jour ?"
for i in "${!BOXES[@]}"; do
  printf "%2d) %s\n" "$((i+1))" "${BOXES[$i]}"
done
echo " a) Tous"
echo " q) Quitter"
read -rp "> " choix

case "$choix" in
  q|Q)
    exit 0
    ;;
  a|A)
    for box in "${BOXES[@]}"; do
      do_update "$box"
    done
    echo ""
    echo "Tous les environnements sont à jour."
    ;;
  *)
    if [[ "$choix" =~ ^[0-9]+$ ]] && (( choix >= 1 && choix <= ${#BOXES[@]} )); then
      do_update "${BOXES[$((choix-1))]}"
    else
      echo "Choix invalide." >&2
      exit 1
    fi
    ;;
esac
