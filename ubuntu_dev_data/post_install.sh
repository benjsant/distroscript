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

# uv (gestionnaire de venvs / installeur ultra-rapide)
if ! command -v uv &>/dev/null && [ ! -f "$LOCAL_BIN/uv" ]; then
  echo "Installation de uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$LOCAL_BIN:$PATH"

# DuckDB CLI
if ! command -v duckdb &>/dev/null; then
  echo "Installation de DuckDB CLI..."
  DUCK_VER="$(curl -fsSL https://api.github.com/repos/duckdb/duckdb/releases/latest | jq -r .tag_name)"
  curl -fsSL "https://github.com/duckdb/duckdb/releases/download/${DUCK_VER}/duckdb_cli-linux-amd64.zip" -o /tmp/duckdb.zip
  unzip -o /tmp/duckdb.zip -d "$LOCAL_BIN"
  rm -f /tmp/duckdb.zip
fi

# CLIs SQL via uv tool (isolés, mises à jour faciles)
uv tool install pgcli      2>/dev/null || uv tool upgrade pgcli
uv tool install mycli      2>/dev/null || uv tool upgrade mycli
uv tool install litecli    2>/dev/null || uv tool upgrade litecli
uv tool install harlequin  2>/dev/null || uv tool upgrade harlequin

# Venv "data_env" prêt à l'emploi avec la stack d'analyse classique
DATA_VENV="$HOME/data_env"
if [ ! -d "$DATA_VENV" ]; then
  echo "Création du venv $DATA_VENV..."
  uv venv "$DATA_VENV" --python "${PYTHON_VERSION%.*}"
fi

# shellcheck disable=SC1091
source "$DATA_VENV/bin/activate"
uv pip install --upgrade \
  jupyterlab \
  ipykernel \
  pandas \
  polars \
  duckdb \
  pyarrow \
  numpy \
  matplotlib \
  seaborn \
  plotly \
  scikit-learn \
  sqlalchemy \
  psycopg2-binary \
  pymysql \
  requests \
  httpx \
  rich
python -m ipykernel install --user --name data_env --display-name "Python (data_env)" 2>/dev/null || true
deactivate

# .bashrc
if ! grep -q 'HOME/.local/bin' ~/.bashrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

if ! grep -q 'PS1=.*📦' ~/.bashrc; then
  echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
fi

if ! grep -q "alias code=" ~/.bashrc; then
  echo "alias code='code --no-sandbox'" >> ~/.bashrc
fi

if ! grep -q "alias data-env=" ~/.bashrc; then
  echo "alias data-env='source ~/data_env/bin/activate'" >> ~/.bashrc
fi

# Zsh
if command -v zsh &>/dev/null && [ ! -f ~/.zshrc ]; then
  cat > ~/.zshrc << 'EOF'
export PATH="$HOME/.local/bin:$PATH"
alias code='code --no-sandbox'
alias ll='ls -lah'
alias data-env='source ~/data_env/bin/activate'
export PROMPT='[%n@%m %1~]%# '
EOF
  chsh -s "$(which zsh)" 2>/dev/null || true
fi

echo "Installation data terminée."
echo "Activer le venv : data-env  (ou source ~/data_env/bin/activate)"
