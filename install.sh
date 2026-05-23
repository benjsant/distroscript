#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

if [ "$EUID" -eq 0 ]; then
  echo "Ce script ne doit pas être lancé en tant que root." >&2
  exit 1
fi

if ! command -v distrobox >/dev/null 2>&1; then
  echo "distrobox est introuvable." >&2
  exit 1
fi

if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  echo "Aucun moteur de conteneur compatible (podman ou docker) détecté." >&2
  exit 1
fi

if [ ! -d "$HOME/distrobox" ]; then
  mkdir -p "$HOME/distrobox"
fi

echo "Prérequis OK"
echo ""

# VS Code sur l'hôte
if ! command -v code &>/dev/null; then
  read -rp "VS Code n'est pas installé sur l'hôte. Voulez-vous l'installer ? [o/N] " install_vscode
  if [[ "$install_vscode" =~ ^[oOyY]$ ]]; then
    if command -v dnf &>/dev/null; then
      sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
      sudo sh -c 'cat > /etc/yum.repos.d/vscode.repo << EOF
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF'
      sudo dnf install -y code
    elif command -v apt &>/dev/null; then
      curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
      sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
      rm -f /tmp/microsoft.gpg
      sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
      sudo apt update
      sudo apt install -y code
    else
      echo "Gestionnaire de paquets non reconnu. Installez VS Code manuellement." >&2
    fi
    command -v code &>/dev/null && echo "VS Code installé." || echo "Installation échouée." >&2
  fi
else
  echo "VS Code déjà présent sur l'hôte."
fi

echo "Quelle distrobox installer ?"
echo " 1) ubuntu_dev_hugo"
echo " 2) ubuntu_dev_python"
echo " 3) ubuntu_dev_ia"
echo " 4) ubuntu_dev_rust"
echo " 5) ubuntu_dev_n8n"
echo " 6) ubuntu_dev_go"
echo " 7) ubuntu_dev_devops"
echo " 8) ubuntu_dev_dotnet"
echo " 9) ubuntu_dev_writing"
echo "10) ubuntu_dev_data"
echo "11) ubuntu_dev_php"
echo "12) ubuntu_dev_java"
echo "13) ubuntu_dev_video"
echo "14) ubuntu_dev_security_audit"
echo " q) Quitter"
read -rp "> " choix

case "$choix" in
  1)
    "$SCRIPT_DIR/ubuntu_dev_hugo/install.sh"
    ;;
  2)
    "$SCRIPT_DIR/ubuntu_dev_python/install.sh"
    ;;
  3)
    "$SCRIPT_DIR/ubuntu_dev_ia/install.sh"
    ;;
  4)
    "$SCRIPT_DIR/ubuntu_dev_rust/install.sh"
    ;;
  5)
    "$SCRIPT_DIR/ubuntu_dev_n8n/install.sh"
    ;;
  6)
    "$SCRIPT_DIR/ubuntu_dev_go/install.sh"
    ;;
  7)
    "$SCRIPT_DIR/ubuntu_dev_devops/install.sh"
    ;;
  8)
    "$SCRIPT_DIR/ubuntu_dev_dotnet/install.sh"
    ;;
  9)
    "$SCRIPT_DIR/ubuntu_dev_writing/install.sh"
    ;;
  10)
    "$SCRIPT_DIR/ubuntu_dev_data/install.sh"
    ;;
  11)
    "$SCRIPT_DIR/ubuntu_dev_php/install.sh"
    ;;
  12)
    "$SCRIPT_DIR/ubuntu_dev_java/install.sh"
    ;;
  13)
    "$SCRIPT_DIR/ubuntu_dev_video/install.sh"
    ;;
  14)
    "$SCRIPT_DIR/ubuntu_dev_security_audit/install.sh"
    ;;
  q|Q)
    exit 0
    ;;
  *)
    echo "Choix invalide." >&2
    exit 1
    ;;
esac

echo ""
echo "Terminé. Utilisez 'distrobox enter <nom>' pour y accéder."
