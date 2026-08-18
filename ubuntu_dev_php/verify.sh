#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v php &>/dev/null       && php -v | head -1 | sed 's/^/  [ok] /' || echo '  [!!] php manquant'
  command -v composer &>/dev/null  && echo '  [ok] composer'         || echo '  [!!] composer manquant'
  command -v symfony &>/dev/null   && echo '  [ok] symfony cli'      || echo '  [!!] symfony cli manquant'
  command -v laravel &>/dev/null   && echo '  [ok] laravel installer' || echo '  [!!] laravel manquant'
  php -m 2>/dev/null | grep -qi xdebug && echo '  [ok] xdebug'       || echo '  [!!] xdebug manquant'
  command -v gh &>/dev/null        && echo '  [ok] gh'               || echo '  [!!] gh manquant'
