#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v ollama &>/dev/null         && echo '  [ok] Ollama'   || echo '  [!!] Ollama manquant'
  [ -d $HOME/.pyenv ]                  && echo '  [ok] pyenv'    || echo '  [!!] pyenv manquant'
  $HOME/.pyenv/shims/python3 -c 'import torch; print(\"  [ok] PyTorch\", torch.__version__)' 2>/dev/null \
    || echo '  [!!] PyTorch manquant'
  [ -f $HOME/.local/bin/uv ]           && echo '  [ok] uv'       || echo '  [!!] uv manquant'
  [ -d $HOME/ia_env ]                  && echo '  [ok] venv ia_env' || echo '  [!!] venv ia_env manquant'
  command -v gh &>/dev/null             && echo '  [ok] gh'       || echo '  [!!] gh manquant'
