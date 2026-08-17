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
      curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
      sudo install -o root -g root -m 644 /tmp/microsoft.gpg /etc/apt/trusted.gpg.d/
      rm -f /tmp/microsoft.gpg
      sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
      sudo apt-get update
      sudo apt-get install -y code
    else
      echo "Gestionnaire de paquets non reconnu. Installez VS Code manuellement." >&2
    fi
    command -v code &>/dev/null && echo "VS Code installé." || echo "Installation échouée." >&2
  fi
else
  echo "VS Code déjà présent sur l'hôte."
fi

# Auto-discovery : tous les dossiers contenant un install.sh, sauf le install.sh racine.
# fedora_gaming est exclu : il a des pré-requis lourds (systemd + D-Bus session) et
# reste accessible directement via ./fedora_gaming/install.sh.
mapfile -t BOXES < <(
  find "$SCRIPT_DIR" -maxdepth 2 -name install.sh -not -path "$SCRIPT_DIR/install.sh" \
    -printf '%h\n' | xargs -n1 basename | grep -v '^fedora_gaming$' | sort
)

if [ ${#BOXES[@]} -eq 0 ]; then
  echo "Aucun environnement trouvé." >&2
  exit 1
fi

echo "Quelle distrobox installer ?"
for i in "${!BOXES[@]}"; do
  printf "%2d) %s\n" "$((i+1))" "${BOXES[$i]}"
done
echo " q) Quitter"
read -rp "> " choix

case "$choix" in
  q|Q)
    exit 0
    ;;
  *)
    if [[ "$choix" =~ ^[0-9]+$ ]] && (( choix >= 1 && choix <= ${#BOXES[@]} )); then
      box_dir="$SCRIPT_DIR/${BOXES[$((choix-1))]}"

      # Profils optionnels : un env qui expose des packages.<profil>.txt propose
      # ces profils en plus du profil "base" (ex: ubuntu_dev_python --profile data).
      mapfile -t PROFILES < <(
        find "$box_dir" -maxdepth 1 -name 'packages.*.txt' -printf '%f\n' 2>/dev/null \
          | sed -E 's/^packages\.(.*)\.txt$/\1/' | sort
      )

      if [ ${#PROFILES[@]} -gt 0 ]; then
        echo ""
        echo "Cet environnement propose plusieurs profils :"
        echo "  1) base (par défaut)"
        for i in "${!PROFILES[@]}"; do
          printf "  %d) %s\n" "$((i+2))" "${PROFILES[$i]}"
        done
        read -rp "> " prof_choix
        if [[ "$prof_choix" =~ ^[0-9]+$ ]] && (( prof_choix >= 2 && prof_choix <= ${#PROFILES[@]} + 1 )); then
          "$box_dir/install.sh" --profile "${PROFILES[$((prof_choix-2))]}"
        else
          "$box_dir/install.sh"
        fi
      else
        "$box_dir/install.sh"
      fi
    else
      echo "Choix invalide." >&2
      exit 1
    fi
    ;;
esac

echo ""
echo "Terminé. Utilisez 'distrobox enter <nom>' pour y accéder."
