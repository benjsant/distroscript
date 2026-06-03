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

# uv (gestion isolée des outils Python)
if ! command -v uv &>/dev/null && [ ! -f "$LOCAL_BIN/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Trivy (apt repo Aqua Security)
if ! command -v trivy &>/dev/null; then
  echo "Installation de Trivy..."
  curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo gpg --dearmor -o /usr/share/keyrings/trivy.gpg
  echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" \
    | sudo tee /etc/apt/sources.list.d/trivy.list >/dev/null
  sudo apt update
  sudo apt install -y trivy
fi

# Syft (Anchore) — installer script officiel
if ! command -v syft &>/dev/null; then
  echo "Installation de Syft..."
  curl -fsSL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sh -s -- -b "$LOCAL_BIN"
fi

# Grype (Anchore)
if ! command -v grype &>/dev/null; then
  echo "Installation de Grype..."
  curl -fsSL https://raw.githubusercontent.com/anchore/grype/main/install.sh \
    | sh -s -- -b "$LOCAL_BIN"
fi

# Cosign (Sigstore)
if ! command -v cosign &>/dev/null; then
  echo "Installation de Cosign..."
  COSIGN_VER="$(curl -fsSL https://api.github.com/repos/sigstore/cosign/releases/latest | jq -r .tag_name)"
  curl -fsSL "https://github.com/sigstore/cosign/releases/download/${COSIGN_VER}/cosign-linux-amd64" \
    -o "$LOCAL_BIN/cosign"
  chmod +x "$LOCAL_BIN/cosign"
fi

# Gitleaks
if ! command -v gitleaks &>/dev/null; then
  echo "Installation de Gitleaks..."
  GL_VER="$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r .tag_name | sed 's/^v//')"
  tmp_tgz="$(mktemp --suffix=.tgz)"
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_linux_x64.tar.gz" \
    -o "$tmp_tgz"
  tar -xzf "$tmp_tgz" -C "$LOCAL_BIN" gitleaks
  rm -f "$tmp_tgz"
fi

# TruffleHog (autre détection de secrets, complémentaire à gitleaks)
if ! command -v trufflehog &>/dev/null; then
  echo "Installation de TruffleHog..."
  curl -fsSL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
    | sh -s -- -b "$LOCAL_BIN"
fi

# Semgrep via uv (isolé, sans conflit système)
uv tool install semgrep 2>/dev/null || uv tool upgrade semgrep

# Checkov (IaC scanner) via uv
uv tool install checkov 2>/dev/null || uv tool upgrade checkov

setup_prompt_and_aliases
setup_zsh_with_body </dev/null

echo "Installation security_audit terminée."
echo "Astuce :  trivy fs .   |  gitleaks dir .   |  semgrep scan ."
