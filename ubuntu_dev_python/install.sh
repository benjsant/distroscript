#!/bin/bash
set -euo pipefail

BOX_NAME="ubuntu_dev_python"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
LIB_DIR="$SCRIPT_DIR/../lib"
HOME_DIR="$HOME/distrobox/$BOX_NAME"
LOG_FILE="$HOME/distrobox/${BOX_NAME}_install.log"

# Profil : "base" (défaut) ou "data".
# Le profil data ajoute DuckDB, JupyterLab, les CLIs SQL et un venv ~/data_env
# (il remplace l'ancienne box ubuntu_dev_data).
PROFILE="base"
while [ $# -gt 0 ]; do
  case "$1" in
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --profile=*)
      PROFILE="${1#*=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--profile base|data]"
      exit 0
      ;;
    *)
      echo "Option inconnue : $1" >&2
      echo "Usage: $0 [--profile base|data]" >&2
      exit 1
      ;;
  esac
done

case "$PROFILE" in
  base|data) ;;
  *)
    echo "Profil inconnu : '$PROFILE' (attendu : base ou data)" >&2
    exit 1
    ;;
esac

source "$LIB_DIR/common.sh"
source "$LIB_DIR/versions.sh"

check_not_root
force_utf8_locale
enable_logging "$LOG_FILE"
print_host_summary
echo "Profil : $PROFILE"
check_locale_for_ubuntu_box
check_or_recreate_box "$BOX_NAME" "$HOME_DIR"

mkdir -p "$HOME_DIR"
cp "$SCRIPT_DIR/post_install.sh" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.txt" "$HOME_DIR/"
cp "$SCRIPT_DIR/packages.data.txt" "$HOME_DIR/"
cp "$LIB_DIR/versions.sh" "$HOME_DIR/"
cp "$LIB_DIR/shell_setup.sh" "$HOME_DIR/"
cp "$LIB_DIR/fetch.sh" "$HOME_DIR/"

# Mémorise le profil : update.sh le relit pour savoir quoi mettre à jour
echo "$PROFILE" > "$HOME_DIR/.profile_name"

EXTRA_FLAGS=""
detect_nvidia

echo "Création de la distrobox '$BOX_NAME'..."

distrobox-create \
  --name "$BOX_NAME" \
  --image "$UBUNTU_IMAGE" \
  --home "$HOME_DIR" \
  --additional-flags "$EXTRA_FLAGS"

echo "Lancement du post-install..."

distrobox enter "$BOX_NAME" -- bash -c "bash ~/post_install.sh $PROFILE"

echo "Vérification..."
distrobox enter "$BOX_NAME" -- bash -ic "
  [ -d \$HOME/.pyenv ]              && echo '  [ok] pyenv' || echo '  [!!] pyenv manquant'
  [ -d \$HOME/.nvm ]                && echo '  [ok] NVM'   || echo '  [!!] NVM manquant'
  [ -f \$HOME/.local/bin/uv ]       && echo '  [ok] uv'    || echo '  [!!] uv manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'    || echo '  [!!] gh manquant'
" 2>/dev/null || true

if [ "$PROFILE" = "data" ]; then
  distrobox enter "$BOX_NAME" -- bash -ic "
    command -v duckdb &>/dev/null     && echo '  [ok] duckdb'    || echo '  [!!] duckdb manquant'
    command -v pgcli &>/dev/null      && echo '  [ok] pgcli'     || echo '  [!!] pgcli manquant'
    command -v mycli &>/dev/null      && echo '  [ok] mycli'     || echo '  [!!] mycli manquant'
    command -v litecli &>/dev/null    && echo '  [ok] litecli'   || echo '  [!!] litecli manquant'
    command -v harlequin &>/dev/null  && echo '  [ok] harlequin' || echo '  [!!] harlequin manquant'
    [ -d \$HOME/data_env ]            && echo '  [ok] venv data_env' || echo '  [!!] venv data_env manquant'
  " 2>/dev/null || true
fi

echo ""
echo "Distrobox '$BOX_NAME' prête (profil $PROFILE). Log : $LOG_FILE"
if [ "$PROFILE" = "data" ]; then
  echo "Activer le venv d'analyse : data-env  (ou source ~/data_env/bin/activate)"
fi
