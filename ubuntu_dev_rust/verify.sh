#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v rustc &>/dev/null   && rustc --version | sed 's/^/  [ok] /' || echo '  [!!] rustc manquant'
  command -v cargo &>/dev/null   && echo '  [ok] cargo'  || echo '  [!!] cargo manquant'
  command -v rustfmt &>/dev/null && echo '  [ok] rustfmt' || echo '  [!!] rustfmt manquant'
  command -v gh &>/dev/null      && echo '  [ok] gh'     || echo '  [!!] gh manquant'
