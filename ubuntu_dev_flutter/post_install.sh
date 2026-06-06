#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable." >&2
  exit 1
fi

# 1. Système
sudo apt-get update && sudo apt-get upgrade -y
grep -v '^\s*#' "$PACKAGE_FILE" | grep -v '^\s*$' | xargs -r sudo apt-get install -y

setup_local_bin

# 2. Google Chrome (Flutter cherche "google-chrome" pour le device "chrome")
if ! command -v google-chrome &>/dev/null; then
  echo "Installation de Google Chrome (pour Flutter web)..."
  tmp_deb="$(mktemp --suffix=.deb)"
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o "$tmp_deb"
  sudo apt-get install -y "$tmp_deb"
  rm -f "$tmp_deb"
fi

# 3. Flutter SDK : git clone du repo officiel sur le canal demandé
FLUTTER_ROOT="$HOME/.local/flutter"
if [ ! -d "$FLUTTER_ROOT" ]; then
  echo "Clonage du SDK Flutter (canal: $FLUTTER_CHANNEL)..."
  git clone --depth 1 -b "$FLUTTER_CHANNEL" https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
else
  echo "Mise à jour du SDK Flutter..."
  git -C "$FLUTTER_ROOT" fetch --depth 1 origin "$FLUTTER_CHANNEL"
  git -C "$FLUTTER_ROOT" checkout "$FLUTTER_CHANNEL"
  git -C "$FLUTTER_ROOT" pull --ff-only origin "$FLUTTER_CHANNEL" || true
fi

# 4. Trust dir Git (Flutter le demande sinon il refuse de tourner)
git config --global --add safe.directory "$FLUTTER_ROOT"

# 5. Exports + init env
if ! grep -q 'FLUTTER_ROOT=' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
export FLUTTER_ROOT="$HOME/.local/flutter"
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$HOME/.pub-cache/bin:$PATH"
EOF
fi

export FLUTTER_ROOT="$HOME/.local/flutter"
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$HOME/.pub-cache/bin:$PATH"

# 6. Premier appel : Flutter télécharge Dart SDK + outils internes
echo "Initialisation de Flutter (téléchargement du Dart SDK interne)..."
flutter --version || true
flutter precache --linux --web --no-android --no-ios --no-macos --no-windows --no-fuchsia || true

# 7. Désactivation de la télémétrie + activation Linux desktop + Web
flutter --disable-analytics 2>/dev/null || true
flutter config --no-analytics 2>/dev/null || true
flutter config --enable-linux-desktop
flutter config --enable-web

# 8. Diagnostic non bloquant
flutter doctor -v || true

# 9. Prompt, alias, Zsh
setup_prompt_and_aliases

setup_zsh_with_body <<'EOF'
export FLUTTER_ROOT="$HOME/.local/flutter"
export PATH="$FLUTTER_ROOT/bin:$FLUTTER_ROOT/bin/cache/dart-sdk/bin:$HOME/.pub-cache/bin:$PATH"
EOF

cat <<'TIP'

────────────────────────────────────────────────────────────
Installation Flutter terminée (Linux desktop + Web).
  - Créer un projet : flutter create mon_app && cd mon_app
  - Linux desktop  : flutter run -d linux
  - Web (Chromium) : flutter run -d chrome
  - Diagnostic     : flutter doctor

Android n'est PAS installé par défaut (USB/émulateur dans Distrobox
est complexe). Pour l'ajouter manuellement plus tard :
  - Installer 'commandline-tools' depuis developer.android.com
  - sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
  - flutter config --android-sdk ~/Android/Sdk
────────────────────────────────────────────────────────────
TIP
