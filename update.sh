#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root
force_utf8_locale

# Positionné par do_update dès qu'une étape échoue ; lu par le bilan final.
UPDATE_HAD_ERRORS=0

# Auto-discovery : tous les dossiers contenant un install.sh, sauf le install.sh racine
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | sort
)

# ---------- Helpers de mise à jour ----------

# Exécute une étape de mise à jour en tolérant son échec, mais SANS le masquer.
# Auparavant les fonctions se terminaient par `2>/dev/null || true`, ce qui
# avalait à la fois le message d'erreur et le code retour : do_update affichait
# "OK" même quand tout avait échoué. On tolère toujours (une box à moitié à jour
# vaut mieux qu'un script avorté), mais on le dit.
step() {
  local label="$1"
  shift
  if "$@"; then
    return 0
  fi
  echo "  ⚠ échec : $label" >&2
  return 1
}

# apt/dnf/pacman selon la base de la box
update_packages() {
  local name="$1"
  if [[ "$name" == ubuntu_* ]]; then
    distrobox enter "$name" -- bash -c 'sudo apt-get update && sudo apt-get upgrade -y'
  elif [[ "$name" == fedora_* ]]; then
    distrobox enter "$name" -- bash -c 'sudo dnf upgrade -y'
  elif [[ "$name" == arch_* ]]; then
    # Arch ne supporte pas les mises à jour partielles : -Syu est obligatoire.
    distrobox enter "$name" -- bash -c 'sudo pacman -Syu --noconfirm'
  fi
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
    fail=0
    for pkg in golang.org/x/tools/gopls \
               github.com/go-delve/delve/cmd/dlv \
               github.com/air-verse/air \
               honnef.co/go/tools/cmd/staticcheck \
               golang.org/x/tools/cmd/goimports; do
      if ! go install "${pkg}@latest"; then
        echo "    échec : $pkg" >&2
        fail=1
      fi
    done
    exit "$fail"
  '
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
    dotnet tool update --global dotnet-outdated-tool 2>/dev/null || true
  '
}

# Les paquets AUR (Heroic, ProtonPlus) ne sont pas couverts par pacman -Syu.
update_aur() {
  distrobox enter "arch_gaming" -- bash -c '
    command -v paru &>/dev/null || exit 0
    paru -Sua --noconfirm --skipreview || echo "  Mise à jour AUR échouée (non bloquant)." >&2
  '
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
  if ! box_exists "$name"; then
    echo "$name : non installé, ignoré."
    return
  fi
  echo ""
  echo "--- $name ---"
  local status=0
  step "mise à jour des paquets" update_packages "$name" || status=1
  # Chaque étape est encapsulée dans `step` : son échec est signalé et retenu,
  # sans interrompre les suivantes.
  case "$name" in
    ubuntu_dev_python)
      step "pyenv/uv" update_pyenv_uv "$name" || status=1
      step "nvm"      update_nvm "$name"      || status=1
      # Le profil data ajoute des outils installés via `uv tool`
      if [ "$(cat "$HOME/distrobox/$name/.profile_name" 2>/dev/null)" = "data" ]; then
        step "outils uv (profil data)" update_uv_tools "$name" || status=1
      fi
      ;;
    ubuntu_dev_ia)
      step "pyenv/uv" update_pyenv_uv "$name" || status=1
      step "ollama"   update_ollama            || status=1
      ;;
    ubuntu_dev_rust)            step "rustup" update_rust || status=1 ;;
    ubuntu_dev_go)              step "outils Go" update_go_tools || status=1 ;;
    ubuntu_dev_devops)          : ;;  # apt suffit
    ubuntu_dev_dotnet)          step "outils dotnet" update_dotnet_tools || status=1 ;;
    ubuntu_dev_writing)
      step "nvm"        update_nvm "$name"        || status=1
      step "npm global" update_npm_global "$name" || status=1
      ;;
    ubuntu_dev_php)
      step "composer" update_composer   || status=1
      step "nvm"      update_nvm "$name" || status=1
      ;;
    ubuntu_dev_java)            step "sdkman" update_sdkman || status=1 ;;
    ubuntu_dev_security_audit)  step "outils uv" update_uv_tools "$name" || status=1 ;;
    fedora_gaming)              : ;;  # dnf suffit
    arch_gaming)                step "paquets AUR" update_aur || status=1 ;;
  esac

  if [ "$status" -eq 0 ]; then
    echo "$name : OK"
  else
    echo "$name : terminé AVEC DES ERREURS (voir ci-dessus)" >&2
    UPDATE_HAD_ERRORS=1
  fi
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
    if [ "${UPDATE_HAD_ERRORS:-0}" -eq 0 ]; then
      echo "Tous les environnements sont à jour."
    else
      echo "Terminé, mais au moins un environnement a rencontré des erreurs." >&2
      exit 1
    fi
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
