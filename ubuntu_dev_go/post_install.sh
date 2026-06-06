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

# Go SDK — tarball officiel installé sous ~/.local/go (pas /usr/local pour éviter sudo)
GO_ROOT="$HOME/.local/go"
GO_PATH="$HOME/go"
GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"

CURRENT_VERSION=""
if [ -x "$GO_ROOT/bin/go" ]; then
  CURRENT_VERSION="$("$GO_ROOT/bin/go" version | awk '{print $3}' | sed 's/^go//')"
fi

if [ "$CURRENT_VERSION" != "$GO_VERSION" ]; then
  echo "Installation de Go $GO_VERSION..."
  mkdir -p "$HOME/.local"
  rm -rf "$GO_ROOT"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://go.dev/dl/${GO_TARBALL}" -o "/tmp/${GO_TARBALL}"
  tar -C "$HOME/.local" -xzf "/tmp/${GO_TARBALL}"
  rm -f "/tmp/${GO_TARBALL}"
else
  echo "Go $GO_VERSION déjà installé."
fi

mkdir -p "$GO_PATH/bin"

export GOROOT="$GO_ROOT"
export GOPATH="$GO_PATH"
export PATH="$GO_ROOT/bin:$GO_PATH/bin:$PATH"

# Outils Go
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest
go install github.com/air-verse/air@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
go install golang.org/x/tools/cmd/goimports@latest

# .bashrc
if ! grep -q 'GOROOT=' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
export GOROOT="$HOME/.local/go"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
EOF
fi

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export GOROOT="$HOME/.local/go"
export GOPATH="$HOME/go"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
EOF

echo "Installation terminée. $(go version)"
