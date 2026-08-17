#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

GAMES_DIR="${1:-$HOME/Games}"
PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable : $PACKAGE_FILE" >&2
  exit 1
fi

FEDORA_REL="$(rpm -E %fedora)"

# ---------------------------------------------------------------------------
# 1. Dépôts : RPM Fusion (steam, wine, mesa freeworld) + COPR (heroic, protonplus)
# ---------------------------------------------------------------------------
echo "Activation de RPM Fusion..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_REL}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_REL}.noarch.rpm"

# Les COPR sont des dépôts tiers : s'ils sont cassés sur une release récente de
# Fedora, on continue sans plutôt que de faire échouer toute l'installation.
echo "Activation des dépôts COPR..."
sudo dnf -y copr enable atim/heroic-games-launcher || \
  echo "  ⚠ COPR heroic indisponible pour Fedora ${FEDORA_REL} — Heroic sera ignoré." >&2
sudo dnf -y copr enable wehagy/protonplus || \
  echo "  ⚠ COPR protonplus indisponible pour Fedora ${FEDORA_REL} — ProtonPlus sera ignoré." >&2

sudo dnf upgrade -y

# ---------------------------------------------------------------------------
# 2. Paquets
# ---------------------------------------------------------------------------
# --skip-unavailable : un seul paquet absent (COPR down, renommage entre deux
# releases Fedora) ne doit pas faire échouer les 60 autres. L'ancien script
# faisait un `xargs dnf install` global qui abandonnait tout sur un raté.
echo "Installation des paquets..."
mapfile -t PKGS < <(grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$')
sudo dnf install -y --skip-unavailable "${PKGS[@]}" \
  || sudo dnf install -y --setopt=strict=0 "${PKGS[@]}"

echo ""
echo "Paquets demandés mais non installés :"
missing=0
for p in "${PKGS[@]}"; do
  if ! rpm -q "${p%%.*}" &>/dev/null; then
    echo "  - $p"
    missing=1
  fi
done
[ "$missing" -eq 0 ] && echo "  (aucun)"
echo ""

setup_local_bin

# ---------------------------------------------------------------------------
# 3. Dossier de jeux + préfixes Wine hors du conteneur
# ---------------------------------------------------------------------------
# WINEPREFIX pointe vers GAMES_DIR (monté depuis l'hôte) et non vers ~/.wine :
# les préfixes survivent ainsi à une recréation de la box.
mkdir -p "$GAMES_DIR/prefixes" "$GAMES_DIR/lutris" "$GAMES_DIR/steam"

if ! grep -q 'GAMES_DIR' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<EOF

# --- fedora_gaming ---
export GAMES_DIR="$GAMES_DIR"
export WINEPREFIX="\$GAMES_DIR/prefixes/default"
# Raccourcis : wine64 dans un préfixe nommé, overlay MangoHud
wineprefix() { export WINEPREFIX="\$GAMES_DIR/prefixes/\${1:-default}"; echo "WINEPREFIX=\$WINEPREFIX"; }
alias mangorun='MANGOHUD=1 mangohud --dlsym'
EOF
fi

export GAMES_DIR WINEPREFIX="$GAMES_DIR/prefixes/default"

# ---------------------------------------------------------------------------
# 4. Export des lanceurs vers le menu de l'hôte
# ---------------------------------------------------------------------------
# C'est ce qui rend la box utilisable comme un vrai système de jeu : sans export,
# il faut passer par `distrobox enter` avant chaque lancement.
echo "Export des lanceurs vers l'hôte..."
for app in steam lutris heroic net.davidotek.pupgui2 com.vysp3r.ProtonPlus goverlay antimicrox dolphin-emu ppsspp; do
  if distrobox-export --app "$app" &>/dev/null; then
    echo "  [ok] $app"
  fi
done

# Binaires utiles en ligne de commande depuis l'hôte
for bin in winetricks protontricks mangohud gamescope; do
  command -v "$bin" &>/dev/null && distrobox-export --bin "$(command -v "$bin")" \
    --export-path "$HOME/.local/bin" &>/dev/null || true
done

# ---------------------------------------------------------------------------
# 5. Shell
# ---------------------------------------------------------------------------
setup_prompt_and_aliases

setup_zsh_with_body <<EOF
export GAMES_DIR="$GAMES_DIR"
export WINEPREFIX="\$GAMES_DIR/prefixes/default"
alias mangorun='MANGOHUD=1 mangohud --dlsym'
EOF

echo ""
echo "Post-install gaming terminé."
echo "  Jeux et préfixes Wine : $GAMES_DIR"
echo "  Changer de préfixe    : wineprefix <nom>"
echo "  Overlay MangoHud      : mangorun <commande>"
