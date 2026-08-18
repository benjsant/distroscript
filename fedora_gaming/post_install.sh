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
# 1. Dépôts
# ---------------------------------------------------------------------------
# RPM Fusion : steam, snes9x-gtk, codecs.
echo "Activation de RPM Fusion..."
sudo dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_REL}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_REL}.noarch.rpm"

# Terra (Fyra Labs) : umu-launcher, heroic-games-launcher, protonplus.
# Préféré aux COPR personnels — c'est un dépôt maintenu conçu pour s'ajouter à
# une Fedora standard, là où les COPR gaming répandus (gloriouseggroll) sont des
# overlays de distro complets, déconseillés hors Nobara.
echo "Activation de Terra..."
sudo tee /etc/yum.repos.d/terra.repo >/dev/null <<'EOF'
[terra]
name=Terra $releasever
metalink=https://tetsudou.fyralabs.com/metalink?repo=terra$releasever&arch=$basearch
gpgkey=https://repos.fyralabs.com/terra$releasever/key.asc
gpgcheck=1
enabled=1
EOF

sudo dnf upgrade -y

# ---------------------------------------------------------------------------
# 2. Paquets
# ---------------------------------------------------------------------------
# --skip-unavailable : un seul paquet absent (dépôt tiers indisponible,
# renommage entre deux releases Fedora) ne doit pas faire échouer les 60 autres.
# L'ancien script faisait un `xargs dnf install` global qui abandonnait tout
# sur un raté.
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
# Les noms de fichiers .desktop varient (nom court ou identifiant reverse-DNS)
# selon le paquet et sa version. Plutôt que de maintenir une liste qui se
# désynchronise, on cherche le .desktop réellement installé pour chaque appli.
export_app() {
  local label="$1" desktop
  shift
  for desktop in "$@"; do
    if [ -f "/usr/share/applications/${desktop}.desktop" ] \
       && distrobox-export --app "$desktop" &>/dev/null; then
      echo "  [ok] $label"
      return 0
    fi
  done
  echo "  [--] $label (non installé)"
}

echo "Export des lanceurs vers l'hôte..."
export_app "Steam"      steam
export_app "Lutris"     net.lutris.Lutris lutris
export_app "Heroic"     com.heroicgameslauncher.hgl heroic
export_app "ProtonPlus" com.vysp3r.ProtonPlus protonplus
export_app "Bottles"    com.usebottles.bottles bottles
export_app "GOverlay"   io.github.benjamimgois.goverlay goverlay
export_app "AntiMicroX" io.github.antimicrox.antimicrox antimicrox
export_app "Dolphin"    dolphin-emu

# Binaires utiles en ligne de commande depuis l'hôte
for bin in winetricks protontricks mangohud gamescope umu-run; do
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
