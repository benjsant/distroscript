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
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt-get install -y

# rustup
if [ ! -d "$HOME/.cargo" ]; then
  echo "Installation de rustup..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
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

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
. "$HOME/.cargo/env" 2>/dev/null || true
EOF

echo "Installation terminée. $(rustc --version)"
