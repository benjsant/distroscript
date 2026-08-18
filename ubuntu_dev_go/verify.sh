#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v go &>/dev/null      && go version | sed 's/^/  [ok] /' || echo '  [!!] go manquant'
  command -v gopls &>/dev/null   && echo '  [ok] gopls'   || echo '  [!!] gopls manquant'
  command -v dlv &>/dev/null     && echo '  [ok] delve'   || echo '  [!!] delve manquant'
  command -v air &>/dev/null     && echo '  [ok] air'     || echo '  [!!] air manquant'
  command -v gh &>/dev/null      && echo '  [ok] gh'      || echo '  [!!] gh manquant'
