#!/bin/bash
set -euo pipefail

source ~/versions.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi

sudo apt update && sudo apt upgrade -y
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt install -y

# rustup
if [ ! -d "$HOME/.cargo" ]; then
  echo "Installation de rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

. "$HOME/.cargo/env"

rustup toolchain install stable nightly
rustup default stable
rustup component add rust-analyzer clippy rustfmt

# mold comme linker par défaut (si disponible)
if command -v mold &>/dev/null && [ ! -f "$HOME/.cargo/config.toml" ]; then
  cat > "$HOME/.cargo/config.toml" << 'EOF'
[target.x86_64-unknown-linux-gnu]
rustflags = ["-C", "link-arg=-fuse-ld=mold"]
EOF
fi

# .bashrc
if ! grep -q '\.cargo/env' ~/.bashrc; then
  echo '. "$HOME/.cargo/env"' >> ~/.bashrc
fi

if ! grep -q 'PS1=.*📦' ~/.bashrc; then
  echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

if ! grep -q "alias code=" ~/.bashrc; then
  echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

# Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
  cat > ~/.zshrc << 'EOF'
. "$HOME/.cargo/env" 2>/dev/null || true

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
  chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation terminée. $(rustc --version)"
