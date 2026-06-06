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

# kubectl (stable du jour)
if ! command -v kubectl &>/dev/null; then
  echo "Installation de kubectl..."
  KVER="$(curl --retry 3 --retry-delay 2 --connect-timeout 10 -L -s https://dl.k8s.io/release/stable.txt)"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl" -o "$LOCAL_BIN/kubectl"
  chmod +x "$LOCAL_BIN/kubectl"
fi

# Helm
if ! command -v helm &>/dev/null; then
  echo "Installation de Helm..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Terraform (via HashiCorp apt repo)
if ! command -v terraform &>/dev/null; then
  echo "Installation de Terraform..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt update
  sudo apt install -y terraform
fi

# k9s (tarball)
if ! command -v k9s &>/dev/null; then
  echo "Installation de k9s..."
  K9S_VER="$(curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)"
  tmp_tgz="$(mktemp --suffix=.tgz)"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_amd64.tar.gz" -o "$tmp_tgz"
  tar -xzf "$tmp_tgz" -C "$LOCAL_BIN" k9s
  rm -f "$tmp_tgz"
fi

# Kustomize (script officiel)
if ! command -v kustomize &>/dev/null; then
  echo "Installation de kustomize..."
  ( cd "$LOCAL_BIN" && curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash )
fi

# Kind
if ! command -v kind &>/dev/null; then
  echo "Installation de kind..."
  KIND_VER="$(curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r .tag_name)"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VER}/kind-linux-amd64" -o "$LOCAL_BIN/kind"
  chmod +x "$LOCAL_BIN/kind"
fi

# AWS CLI v2
if ! command -v aws &>/dev/null; then
  echo "Installation d'awscli v2..."
  tmp_zip="$(mktemp --suffix=.zip)"
  tmp_dir="$(mktemp -d)"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmp_zip"
  unzip -q "$tmp_zip" -d "$tmp_dir"
  sudo "$tmp_dir/aws/install" --update
  rm -rf "$tmp_zip" "$tmp_dir"
fi

# Google Cloud CLI
if ! command -v gcloud &>/dev/null; then
  echo "Installation de gcloud CLI..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
  sudo apt update
  sudo apt install -y google-cloud-cli
fi

# Azure CLI
if ! command -v az &>/dev/null; then
  echo "Installation d'Azure CLI..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Completions kubectl/helm/kind + alias k
if ! grep -q 'kubectl completion' ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
# Completions DevOps
source <(kubectl completion bash 2>/dev/null) 2>/dev/null || true
source <(helm completion bash 2>/dev/null) 2>/dev/null || true
source <(kind completion bash 2>/dev/null) 2>/dev/null || true
alias k=kubectl
complete -F __start_kubectl k 2>/dev/null || true
EOF
fi

setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
alias k=kubectl
EOF

echo "Installation DevOps terminée."
