#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v kubectl &>/dev/null    && echo '  [ok] kubectl'    || echo '  [!!] kubectl manquant'
  command -v helm &>/dev/null       && echo '  [ok] helm'       || echo '  [!!] helm manquant'
  command -v terraform &>/dev/null  && echo '  [ok] terraform'  || echo '  [!!] terraform manquant'
  command -v ansible &>/dev/null    && echo '  [ok] ansible'    || echo '  [!!] ansible manquant'
  command -v k9s &>/dev/null        && echo '  [ok] k9s'        || echo '  [!!] k9s manquant'
  command -v kustomize &>/dev/null  && echo '  [ok] kustomize'  || echo '  [!!] kustomize manquant'
  command -v kind &>/dev/null       && echo '  [ok] kind'       || echo '  [!!] kind manquant'
  command -v aws &>/dev/null        && echo '  [ok] aws'        || echo '  [!!] aws manquant'
  command -v gcloud &>/dev/null     && echo '  [ok] gcloud'     || echo '  [!!] gcloud manquant'
  command -v az &>/dev/null         && echo '  [ok] az'         || echo '  [!!] az manquant'
  command -v gh &>/dev/null         && echo '  [ok] gh'         || echo '  [!!] gh manquant'

if [ "${1:-base}" = "cloud" ]; then
  command -v aws &>/dev/null    && echo '  [ok] aws'    || echo '  [!!] aws manquant'
  command -v gcloud &>/dev/null && echo '  [ok] gcloud' || echo '  [!!] gcloud manquant'
  command -v az &>/dev/null     && echo '  [ok] az'     || echo '  [!!] az manquant'
fi
