#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
source "$SCRIPT_DIR/lib/common.sh"

check_not_root

BOXES=("ubuntu_dev_hugo" "ubuntu_dev_python" "ubuntu_dev_ia")

update_apt() {
  local name="$1"
  if distrobox list | grep -q "$name"; then
    echo "📦 Mise à jour apt dans $name..."
    distrobox enter "$name" -- bash -c "sudo apt update && sudo apt upgrade -y"
  fi
}

update_hugo() {
  if distrobox list | grep -q "ubuntu_dev_hugo"; then
    echo "🍺 Mise à jour Homebrew / Hugo..."
    distrobox enter "ubuntu_dev_hugo" -- bash -c "
      eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\" 2>/dev/null || true
      brew upgrade 2>/dev/null || true
    "
  fi
}

update_python_tools() {
  local name="$1"
  if distrobox list | grep -q "$name"; then
    echo "🐍 Mise à jour pyenv + uv dans $name..."
    distrobox enter "$name" -- bash -c "
      [ -d \$HOME/.pyenv ] && git -C \$HOME/.pyenv pull || true
      [ -f \$HOME/.local/bin/uv ] && \$HOME/.local/bin/uv self update || true
    "
  fi
}

update_nvm() {
  local name="$1"
  if distrobox list | grep -q "$name"; then
    echo "🌐 Mise à jour NVM dans $name..."
    distrobox enter "$name" -- bash -c "
      export NVM_DIR=\"\$HOME/.nvm\"
      [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
      command -v nvm &>/dev/null && nvm install --lts --reinstall-packages-from=default 2>/dev/null || true
    "
  fi
}

update_ollama() {
  if distrobox list | grep -q "ubuntu_dev_ia"; then
    echo "🧠 Mise à jour Ollama dans ubuntu_dev_ia..."
    distrobox enter "ubuntu_dev_ia" -- bash -c "
      if command -v ollama &>/dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || true
        echo '📋 Modèles installés :'
        ollama list 2>/dev/null || true
        ollama list 2>/dev/null | tail -n +2 | awk '{print \$1}' | while read -r model; do
          [ -z \"\$model\" ] && continue
          echo \"  🔄 Pull \$model...\"
          ollama pull \"\$model\" || true
        done
      else
        echo '⚠️  Ollama non installé dans ubuntu_dev_ia'
      fi
    "
  fi
}

do_update() {
  local name="$1"
  if ! distrobox list | grep -q "$name"; then
    echo "ℹ️ $name n'existe pas, ignoré."
    return
  fi
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔄 Mise à jour : $name"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  update_apt "$name"
  case "$name" in
    ubuntu_dev_hugo)   update_hugo; update_nvm "$name" ;;
    ubuntu_dev_python) update_python_tools "$name"; update_nvm "$name" ;;
    ubuntu_dev_ia)     update_python_tools "$name"; update_ollama ;;
  esac
  echo "✅ $name mis à jour."
}

echo "🔄 Quel environnement souhaitez-vous mettre à jour ?"
for i in "${!BOXES[@]}"; do
  echo "$((i+1))) ${BOXES[$i]}"
done
echo "a) Tous"
echo "q) Quitter"
read -rp "👉 Votre choix : " choix

case "$choix" in
  1) do_update "${BOXES[0]}" ;;
  2) do_update "${BOXES[1]}" ;;
  3) do_update "${BOXES[2]}" ;;
  a|A)
    for box in "${BOXES[@]}"; do
      do_update "$box"
    done
    echo ""
    echo "✅ Tous les environnements ont été mis à jour."
    ;;
  q|Q)
    echo "👋 Sortie."
    exit 0
    ;;
  *)
    echo "❌ Choix invalide."
    exit 1
    ;;
esac
