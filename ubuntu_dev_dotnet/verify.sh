#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v dotnet &>/dev/null     && dotnet --version | sed 's/^/  [ok] dotnet /' || echo '  [!!] dotnet manquant'
  command -v pwsh &>/dev/null       && pwsh --version | sed 's/^/  [ok] /' || echo '  [!!] pwsh manquant'
  command -v az &>/dev/null         && echo '  [ok] az'      || echo '  [!!] az manquant'
  command -v dotnet-ef &>/dev/null  && echo '  [ok] dotnet-ef' || echo '  [!!] dotnet-ef manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'      || echo '  [!!] gh manquant'
