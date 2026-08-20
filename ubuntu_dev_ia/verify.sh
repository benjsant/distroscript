#!/bin/bash
# Vérification post-install, exécutée DANS la box.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

command -v ollama &>/dev/null && echo '  [ok] Ollama' || echo '  [!!] Ollama manquant'
command -v python &>/dev/null && echo "  [ok] python $(python --version 2>&1 | awk '{print $2}')" \
                              || echo '  [!!] python manquant'
[ -f "$HOME/.local/bin/uv" ]  && echo '  [ok] uv'     || echo '  [!!] uv manquant'
[ -d "$HOME/ia_env" ]         && echo '  [ok] venv ia_env' || echo '  [!!] venv ia_env manquant'
"$HOME/ia_env/bin/python" -c 'import torch; print("  [ok] PyTorch", torch.__version__)' 2>/dev/null \
  || echo '  [!!] PyTorch manquant'
command -v gh &>/dev/null     && echo '  [ok] gh'     || echo '  [!!] gh manquant'
