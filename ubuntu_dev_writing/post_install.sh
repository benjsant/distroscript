#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi

sudo apt update && sudo apt upgrade -y
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt install -y

setup_local_bin

# NVM + Node (pour Marp)
if [ ! -d "$HOME/.nvm" ]; then
  echo "Installation de NVM $NVM_VERSION..."
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

if ! command -v node &>/dev/null; then
  nvm install --lts
fi

# Marp CLI
if ! command -v marp &>/dev/null; then
  echo "Installation de Marp CLI..."
  npm install -g @marp-team/marp-cli
fi

# Vale (binary)
if ! command -v vale &>/dev/null; then
  echo "Installation de Vale..."
  VALE_VER="$(curl -fsSL https://api.github.com/repos/errata-ai/vale/releases/latest | jq -r .tag_name | sed 's/^v//')"
  tmp_tgz="$(mktemp --suffix=.tgz)"
  curl -fsSL "https://github.com/errata-ai/vale/releases/download/v${VALE_VER}/vale_${VALE_VER}_Linux_64-bit.tar.gz" -o "$tmp_tgz"
  tar -xzf "$tmp_tgz" -C "$LOCAL_BIN" vale
  rm -f "$tmp_tgz"
fi

# Pandoc Eisvogel template (template PDF élégant très utilisé)
EISVOGEL_DIR="$HOME/.local/share/pandoc/templates"
if [ ! -f "$EISVOGEL_DIR/eisvogel.latex" ]; then
  echo "Installation du template Pandoc Eisvogel..."
  mkdir -p "$EISVOGEL_DIR"
  EIS_VER="$(curl -fsSL https://api.github.com/repos/Wandmalfarbe/pandoc-latex-template/releases/latest | jq -r .tag_name)"
  tmp_tgz="$(mktemp --suffix=.tgz)"
  tmp_dir="$(mktemp -d)"
  curl -fsSL "https://github.com/Wandmalfarbe/pandoc-latex-template/releases/download/${EIS_VER}/Eisvogel-${EIS_VER#v}.tar.gz" -o "$tmp_tgz"
  tar -xzf "$tmp_tgz" -C "$tmp_dir"
  find "$tmp_dir" -name 'eisvogel.latex' -exec cp {} "$EISVOGEL_DIR/" \;
  rm -rf "$tmp_tgz" "$tmp_dir"
fi

# .bashrc
if ! grep -q 'NVM_DIR' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
fi

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF

echo "Installation writing terminée. $(pandoc --version | head -1)"
