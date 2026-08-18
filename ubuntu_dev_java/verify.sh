#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  [ -d $HOME/.sdkman ]                && echo '  [ok] SDKMAN'    || echo '  [!!] SDKMAN manquant'
  command -v java &>/dev/null          && java --version | head -1 | sed 's/^/  [ok] /' || echo '  [!!] java manquant'
  command -v mvn &>/dev/null           && echo '  [ok] maven'     || echo '  [!!] maven manquant'
  command -v gradle &>/dev/null        && echo '  [ok] gradle'    || echo '  [!!] gradle manquant'
  command -v spring &>/dev/null        && echo '  [ok] spring boot cli' || echo '  [!!] spring boot manquant'
  command -v gh &>/dev/null            && echo '  [ok] gh'        || echo '  [!!] gh manquant'
