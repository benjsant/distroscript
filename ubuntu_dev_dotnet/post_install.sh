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

UBUNTU_VER="$(lsb_release -rs)"

# Microsoft package signing key + repo (commun à dotnet et powershell)
if [ ! -f /etc/apt/sources.list.d/microsoft-prod.list ]; then
  echo "Ajout du dépôt Microsoft..."
  curl -fsSL "https://packages.microsoft.com/config/ubuntu/${UBUNTU_VER}/packages-microsoft-prod.deb" -o /tmp/ms-prod.deb
  sudo dpkg -i /tmp/ms-prod.deb
  rm -f /tmp/ms-prod.deb
  sudo apt update
fi

# .NET SDK (LTS 8.0 par défaut)
if ! command -v dotnet &>/dev/null; then
  echo "Installation du .NET SDK 8.0 (LTS)..."
  sudo apt install -y dotnet-sdk-8.0
fi

# PowerShell
if ! command -v pwsh &>/dev/null; then
  echo "Installation de PowerShell..."
  sudo apt install -y powershell
fi

# Azure CLI
if ! command -v az &>/dev/null; then
  echo "Installation d'Azure CLI..."
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Outils dotnet globaux
export PATH="$HOME/.dotnet/tools:$PATH"
dotnet tool install --global dotnet-ef        2>/dev/null || dotnet tool update --global dotnet-ef
dotnet tool install --global dotnet-format    2>/dev/null || dotnet tool update --global dotnet-format
dotnet tool install --global dotnet-outdated-tool 2>/dev/null || dotnet tool update --global dotnet-outdated-tool

# Désactiver la télémétrie .NET dans la box
if ! grep -q 'DOTNET_CLI_TELEMETRY_OPTOUT' ~/.bashrc; then
  echo 'export DOTNET_CLI_TELEMETRY_OPTOUT=1' >> ~/.bashrc
fi

if ! grep -q '\.dotnet/tools' ~/.bashrc; then
  echo 'export PATH="$HOME/.dotnet/tools:$PATH"' >> ~/.bashrc
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
export PATH="$HOME/.dotnet/tools:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
  chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation .NET terminée. $(dotnet --version)"
