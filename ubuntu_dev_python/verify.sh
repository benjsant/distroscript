#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Reçoit le profil en $1. Volontairement non bloquante : un outil manquant est
# signalé, pas fatal.

PROFILE="${1:-base}"

[ -d "$HOME/.pyenv" ]        && echo '  [ok] pyenv' || echo '  [!!] pyenv manquant'
[ -d "$HOME/.nvm" ]          && echo '  [ok] NVM'   || echo '  [!!] NVM manquant'
[ -f "$HOME/.local/bin/uv" ] && echo '  [ok] uv'    || echo '  [!!] uv manquant'
command -v gh &>/dev/null    && echo '  [ok] gh'    || echo '  [!!] gh manquant'

if [ "$PROFILE" = "data" ]; then
  command -v duckdb &>/dev/null    && echo '  [ok] duckdb'    || echo '  [!!] duckdb manquant'
  command -v pgcli &>/dev/null     && echo '  [ok] pgcli'     || echo '  [!!] pgcli manquant'
  command -v mycli &>/dev/null     && echo '  [ok] mycli'     || echo '  [!!] mycli manquant'
  command -v litecli &>/dev/null   && echo '  [ok] litecli'   || echo '  [!!] litecli manquant'
  command -v harlequin &>/dev/null && echo '  [ok] harlequin' || echo '  [!!] harlequin manquant'
  [ -d "$HOME/data_env" ]          && echo '  [ok] venv data_env' || echo '  [!!] venv data_env manquant'
fi
