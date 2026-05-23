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

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# whisper.cpp — compilation depuis source (binaire CPU portable, rapide)
WHISPER_DIR="$HOME/.local/src/whisper.cpp"
WHISPER_MODELS="$HOME/.local/share/whisper-models"
if [ ! -x "$LOCAL_BIN/whisper-cli" ]; then
  echo "Compilation de whisper.cpp..."
  mkdir -p "$(dirname "$WHISPER_DIR")"
  if [ ! -d "$WHISPER_DIR" ]; then
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$WHISPER_DIR"
  else
    git -C "$WHISPER_DIR" pull --ff-only || true
  fi
  cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DWHISPER_BUILD_EXAMPLES=ON
  cmake --build "$WHISPER_DIR/build" --config Release -j"$(nproc)"
  # Le binaire s appelle 'whisper-cli' depuis le refactor mais le projet a aussi
  # produit 'main' avant. On copie ce qui existe.
  if [ -f "$WHISPER_DIR/build/bin/whisper-cli" ]; then
    cp "$WHISPER_DIR/build/bin/whisper-cli" "$LOCAL_BIN/whisper-cli"
  elif [ -f "$WHISPER_DIR/build/bin/main" ]; then
    cp "$WHISPER_DIR/build/bin/main" "$LOCAL_BIN/whisper-cli"
  fi
fi

# Modèle base (~150 Mo, bon compromis vitesse/qualité)
mkdir -p "$WHISPER_MODELS"
if [ ! -f "$WHISPER_MODELS/ggml-base.bin" ]; then
  echo "Téléchargement du modèle whisper base..."
  curl -fL "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin" \
    -o "$WHISPER_MODELS/ggml-base.bin"
fi

# .bashrc
if ! grep -q 'HOME/.local/bin' ~/.bashrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

if ! grep -q 'WHISPER_MODELS' ~/.bashrc; then
  echo "export WHISPER_MODELS=\"$WHISPER_MODELS\"" >> ~/.bashrc
fi

if ! grep -q 'PS1=.*📦' ~/.bashrc; then
  echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

if ! grep -q "alias code=" ~/.bashrc; then
  echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

if ! grep -q "alias transcribe=" ~/.bashrc; then
  cat >> ~/.bashrc << 'EOF'
# Transcription rapide : transcribe <fichier.mp3|wav|mp4>
transcribe() {
  if [ -z "${1:-}" ]; then echo "usage: transcribe <fichier audio>"; return 1; fi
  local input="$1"
  local wav="/tmp/$(basename "$input").wav"
  ffmpeg -y -i "$input" -ar 16000 -ac 1 -c:a pcm_s16le "$wav" >/dev/null 2>&1
  whisper-cli -m "$WHISPER_MODELS/ggml-base.bin" -f "$wav" -l auto
  rm -f "$wav"
}
EOF
fi

# Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
  cat > ~/.zshrc << EOF
export PATH="\$HOME/.local/bin:\$PATH"
export WHISPER_MODELS="$WHISPER_MODELS"
alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
EOF
  chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation video terminée. Utilise 'transcribe <fichier>' pour tester whisper.cpp."
