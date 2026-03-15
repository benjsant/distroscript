#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

### ❌ Vérification root
if [ "$EUID" -eq 0 ]; then
  echo "❌ Ce script ne doit pas être lancé en tant que root."
  exit 1
fi

### 🔎 Vérification des prérequis
if ! command -v distrobox >/dev/null 2>&1; then
  echo "❌ Distrobox est introuvable."
  exit 1
fi

if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
  echo "❌ Aucun moteur de conteneur compatible (podman ou docker) détecté."
  exit 1
fi

### 📁 Vérification dossier base
if [ ! -d "$HOME/distrobox" ]; then
  echo "📁 Création du dossier $HOME/distrobox"
  mkdir -p "$HOME/distrobox"
fi

echo ""
echo "✅ Prérequis OK"
echo ""

### 🖥️ VS Code sur l'hôte
if ! command -v code &>/dev/null; then
  read -rp "🖥️  VS Code n'est pas installé sur l'hôte. Voulez-vous l'installer maintenant ? [o/N] " install_vscode
  if [[ "$install_vscode" =~ ^[oOyY]$ ]]; then
    if command -v dnf &>/dev/null; then
      echo "🔧 Installation via DNF (Fedora/RHEL)..."
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
      echo "🔧 Installation via APT (Ubuntu/Debian)..."
      wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
      sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
      rm -f /tmp/microsoft.gpg
      sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
      sudo apt update
      sudo apt install -y code
    else
      echo "⚠️  Gestionnaire de paquets non reconnu. Installez VS Code manuellement depuis https://code.visualstudio.com"
    fi
    command -v code &>/dev/null && echo "✅ VS Code installé." || echo "⚠️  Installation échouée."
  fi
else
  echo "✅ VS Code déjà installé sur l'hôte."
fi
echo ""

### 📜 Menu interactif
echo "📦 Quelle Distrobox souhaitez-vous installer ?"
echo "1) Ubuntu Dev Hugo"
echo "2) Ubuntu Dev Python"
echo "3) Ubuntu Dev IA"
echo "q) Quitter"
read -rp "👉 Votre choix : " choix

case "$choix" in
  1)
    echo "🚀 Installation de Ubuntu Dev Hugo..."
    "$SCRIPT_DIR/ubuntu_dev_hugo/install.sh"
    ;;
  2)
    echo "🚀 Installation de Ubuntu Dev Python..."
    "$SCRIPT_DIR/ubuntu_dev_python/install.sh"
    ;;
  3)
    echo "🚀 Installation de Ubuntu Dev IA..."
    "$SCRIPT_DIR/ubuntu_dev_ia/install.sh"
    ;;
  q|Q)
    echo "👋 Sortie du script."
    exit 0
    ;;
  *)
    echo "❌ Choix invalide."
    exit 1
    ;;
esac

echo ""
echo "🎉 Installation terminée ! Utilisez 'distrobox enter <nom>' pour y accéder."
