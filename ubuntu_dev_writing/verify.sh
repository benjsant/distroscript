#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v pandoc &>/dev/null     && pandoc --version | head -1 | sed 's/^/  [ok] /' || echo '  [!!] pandoc manquant'
  command -v xelatex &>/dev/null    && echo '  [ok] xelatex'   || echo '  [!!] xelatex manquant'
  command -v lualatex &>/dev/null   && echo '  [ok] lualatex'  || echo '  [!!] lualatex manquant'
  command -v biber &>/dev/null      && echo '  [ok] biber'     || echo '  [!!] biber manquant'
  command -v marp &>/dev/null       && echo '  [ok] marp'      || echo '  [!!] marp manquant'
  command -v vale &>/dev/null       && echo '  [ok] vale'      || echo '  [!!] vale manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'        || echo '  [!!] gh manquant'
