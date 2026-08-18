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

# ---------------------------------------------------------------------------
# 1. Mise à jour de la base
# ---------------------------------------------------------------------------
# Arch ne supporte pas les mises à jour partielles : un `pacman -S` sur une base
# non synchronisée casse les dépendances. -Syu est donc obligatoire, pas optionnel.
echo "Synchronisation des dépôts..."
sudo pacman -Syu --noconfirm

# ---------------------------------------------------------------------------
# 2. Paquets complémentaires
# ---------------------------------------------------------------------------
mapfile -t PKGS < <(grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$')

# wine-staging entre en conflit avec le wine stable fourni par l'image.
# On le traite à part : --noconfirm accepte le remplacement, et un échec ne doit
# pas empêcher l'installation du reste.
WINE_STAGING=0
FILTERED=()
for p in "${PKGS[@]}"; do
  if [ "$p" = "wine-staging" ]; then WINE_STAGING=1; else FILTERED+=("$p"); fi
done

echo "Installation des paquets complémentaires..."
sudo pacman -S --needed --noconfirm "${FILTERED[@]}"

if [ "$WINE_STAGING" -eq 1 ]; then
  echo "Passage à wine-staging (remplace le wine stable de l'image)..."
  if sudo pacman -S --noconfirm wine-staging; then
    echo "  [ok] wine-staging $(wine --version 2>/dev/null || echo '')"
  else
    echo "  ⚠ Échec du passage à wine-staging — le wine stable reste en place." >&2
  fi
fi

echo ""
echo "Paquets demandés mais non installés :"
missing=0
for p in "${PKGS[@]}"; do
  if ! pacman -Q "$p" &>/dev/null; then
    echo "  - $p"
    missing=1
  fi
done
[ "$missing" -eq 0 ] && echo "  (aucun)"
echo ""

# ---------------------------------------------------------------------------
# 3. AUR (optionnel) — paru est fourni par l'image
# ---------------------------------------------------------------------------
# Heroic et ProtonPlus ne sont pas dans les dépôts officiels. La compilation AUR
# est longue et peut échouer : elle ne doit jamais bloquer le post-install.
if command -v paru &>/dev/null; then
  echo "Installation depuis l'AUR (peut être long, échec non bloquant)..."
  for aur in heroic-games-launcher-bin protonplus; do
    if paru -S --needed --noconfirm --skipreview "$aur" &>/dev/null; then
      echo "  [ok] $aur"
    else
      echo "  [--] $aur (échec AUR, ignoré)"
    fi
  done
else
  echo "paru absent — Heroic et ProtonPlus non installés."
fi

setup_local_bin

# ---------------------------------------------------------------------------
# 4. Dossier de jeux + préfixes Wine hors du conteneur
# ---------------------------------------------------------------------------
mkdir -p "$GAMES_DIR/prefixes" "$GAMES_DIR/lutris" "$GAMES_DIR/steam"

if ! grep -q 'GAMES_DIR' ~/.bashrc 2>/dev/null; then
  cat >> ~/.bashrc <<EOF

# --- arch_gaming ---
export GAMES_DIR="$GAMES_DIR"
export WINEPREFIX="\$GAMES_DIR/prefixes/default"
wineprefix() { export WINEPREFIX="\$GAMES_DIR/prefixes/\${1:-default}"; echo "WINEPREFIX=\$WINEPREFIX"; }
alias mangorun='MANGOHUD=1 mangohud --dlsym'
EOF
fi

export GAMES_DIR WINEPREFIX="$GAMES_DIR/prefixes/default"

# ---------------------------------------------------------------------------
# 5. Export des lanceurs vers le menu de l'hôte
# ---------------------------------------------------------------------------
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
export_app "GOverlay"   io.github.benjamimgois.goverlay goverlay
export_app "AntiMicroX" io.github.antimicrox.antimicrox antimicrox
export_app "RetroArch"  retroarch
export_app "Dolphin"    dolphin-emu

for bin in winetricks protontricks mangohud gamescope umu-run steamcmd; do
  command -v "$bin" &>/dev/null && distrobox-export --bin "$(command -v "$bin")" \
    --export-path "$HOME/.local/bin" &>/dev/null || true
done

# ---------------------------------------------------------------------------
# 6. Shell
# ---------------------------------------------------------------------------
setup_prompt_and_aliases

setup_zsh_with_body <<EOF
export GAMES_DIR="$GAMES_DIR"
export WINEPREFIX="\$GAMES_DIR/prefixes/default"
alias mangorun='MANGOHUD=1 mangohud --dlsym'
EOF

echo ""
echo "Post-install arch_gaming terminé."
echo "  Jeux et préfixes Wine : $GAMES_DIR"
echo "  Changer de préfixe    : wineprefix <nom>"
echo "  Overlay MangoHud      : mangorun <commande>"
