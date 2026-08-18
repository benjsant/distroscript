#!/bin/bash
# Vérification post-install, exécutée DANS la box par lib/box_common.sh.
# Volontairement non bloquante : un outil manquant est signalé, pas fatal.

  command -v trivy &>/dev/null     && echo '  [ok] trivy'    || echo '  [!!] trivy manquant'
  command -v syft &>/dev/null      && echo '  [ok] syft'     || echo '  [!!] syft manquant'
  command -v grype &>/dev/null     && echo '  [ok] grype'    || echo '  [!!] grype manquant'
  command -v semgrep &>/dev/null   && echo '  [ok] semgrep'  || echo '  [!!] semgrep manquant'
  command -v cosign &>/dev/null    && echo '  [ok] cosign'   || echo '  [!!] cosign manquant'
  command -v gitleaks &>/dev/null  && echo '  [ok] gitleaks' || echo '  [!!] gitleaks manquant'
  command -v trufflehog &>/dev/null && echo '  [ok] trufflehog' || echo '  [!!] trufflehog manquant'
  command -v gh &>/dev/null        && echo '  [ok] gh'       || echo '  [!!] gh manquant'
