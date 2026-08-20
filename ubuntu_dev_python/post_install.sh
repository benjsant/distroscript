#!/bin/bash
set -euo pipefail

source ~/versions.sh
source ~/shell_setup.sh
source ~/fetch.sh

# Profil : "base" (défaut) ou "data" (ajoute DuckDB, JupyterLab, CLIs SQL, venv data_env)
PROFILE="${1:-base}"

PACKAGE_FILE="$HOME/packages.txt"

if [ ! -f "$PACKAGE_FILE" ]; then
  echo "packages.txt introuvable : $PACKAGE_FILE" >&2
  exit 1
fi

# 1. Système
sudo apt-get update && sudo apt-get upgrade -y
apt_install_from ~/packages_common.txt ~/packages.txt

if [ "$PROFILE" = "data" ] && [ -f "$HOME/packages.data.txt" ]; then
  echo "Profil data : installation des paquets additionnels..."
  apt_install_from "$HOME/packages.data.txt"
fi

setup_local_bin

# 2. Installation des managers (uv, NVM)
# uv remplace pyenv : il télécharge des binaires précompilés (python-build-standalone)
# là où pyenv compilait depuis les sources, soit ~2 secondes contre plusieurs
# minutes, et sans la douzaine de -dev nécessaires à la compilation.
if ! box_has_bin uv; then
  echo "Installation de uv..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$LOCAL_BIN:$PATH"

# NVM_DIR doit être exporté AVANT l'installeur : depuis la v0.40.4, NVM
# s'installe par défaut dans $XDG_CONFIG_HOME/nvm (~/.config/nvm) et non plus
# dans ~/.nvm. Sans ça, tout le reste du projet cherche au mauvais endroit.
export NVM_DIR="$HOME/.nvm"
# Le dossier doit exister AVANT l'installeur : celui-ci refuse de démarrer si
# NVM_DIR est défini mais absent ("that directory does not exist").
mkdir -p "$NVM_DIR"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  echo "Installation de NVM $NVM_VERSION..."
  curl --retry 3 --retry-delay 2 --connect-timeout 10 -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

# 3. .bashrc : exports et hooks
if ! grep -q 'NVM_DIR' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
EOF
fi

# 4. Init env pour la suite du script
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# 5. Runtimes : Python via uv, Node via NVM
# --default installe aussi les exécutables python/python3 dans ~/.local/bin,
# déjà présent dans le PATH via setup_local_bin.
echo "Installation de Python $PYTHON_VERSION via uv..."
uv python install "$PYTHON_VERSION" --default

if ! command -v node &>/dev/null; then
  nvm install --lts
fi

# 6. Profil data : DuckDB, CLIs SQL, venv d'analyse
if [ "$PROFILE" = "data" ]; then
  export PATH="$LOCAL_BIN:$PATH"

  # DuckDB CLI
  if ! box_has_bin duckdb; then
    echo "Installation de DuckDB CLI..."
    DUCK_VER="$(github_latest_tag duckdb/duckdb "$DUCKDB_FALLBACK")"
    tmp_zip="$(mktemp --suffix=.zip)"
    download_file "https://github.com/duckdb/duckdb/releases/download/${DUCK_VER}/duckdb_cli-linux-amd64.zip" \
      "$tmp_zip"
    unzip -o "$tmp_zip" -d "$LOCAL_BIN"
    rm -f "$tmp_zip"
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
    uv venv "$DATA_VENV" --python "$PYTHON_VERSION"
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

  if ! grep -q "alias data-env=" ~/.bashrc; then
    echo "alias data-env='source ~/data_env/bin/activate'" >> ~/.bashrc
  fi
fi

# 7. Prompt, alias et Zsh : en dernier
setup_prompt_and_aliases

{
  cat <<'EOF'
export PATH="$HOME/.local/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
  if [ "$PROFILE" = "data" ]; then
    echo "alias data-env='source ~/data_env/bin/activate'"
  fi
} | setup_zsh_with_body

echo "Installation terminée (profil $PROFILE). Python $(python --version 2>&1)  Node $(node --version 2>/dev/null || echo '(absent)')"
if [ "$PROFILE" = "data" ]; then
  echo "Activer le venv d'analyse : data-env  (ou source ~/data_env/bin/activate)"
fi
