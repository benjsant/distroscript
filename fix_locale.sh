#!/bin/bash
# Met /etc/locale.conf en forme canonique (ex: fr_FR.UTF-8 au lieu de fr_FR.utf8).
# Contourne le bug distrobox-init/update-locale qui rejette la forme non canonique.
#
# Usage :
#   ./fix_locale.sh             # mode interactif (diagnostic + propose le fix)
#   ./fix_locale.sh --apply     # applique directement
#   ./fix_locale.sh --rollback  # restaure le backup
#   ./fix_locale.sh --status    # n'affiche que le diagnostic

set -euo pipefail

LOCALE_FILE="/etc/locale.conf"
BACKUP_FILE="/etc/locale.conf.bak.distroscript"

# Convertit fr_FR.utf8 -> fr_FR.UTF-8 (et autres encodages avec tiret)
canonicalize() {
  # Remplace ".utf8" (insensible casse, en fin de valeur) par ".UTF-8"
  sed -E 's/\.(utf8|UTF8)([^A-Za-z0-9_-]|$)/.UTF-8\2/gI'
}

print_status() {
  echo "=== État actuel ==="
  if [ -r "$LOCALE_FILE" ]; then
    echo "Fichier : $LOCALE_FILE"
    cat "$LOCALE_FILE"
  else
    echo "$LOCALE_FILE introuvable ou illisible."
  fi
  echo "---"
  if command -v localectl &>/dev/null; then
    localectl status || true
    echo "---"
  fi
  echo "Locales disponibles (filtre _FR / _US) :"
  locale -a 2>/dev/null | grep -iE '_(FR|US)' || echo "  (aucune)"
}

needs_fix() {
  [ -r "$LOCALE_FILE" ] || return 1
  # Renvoie 0 si on trouve au moins une ligne LANG=...utf8 / .UTF8 non canonique
  grep -Eiq '^[A-Z_]+=.*\.(utf8|UTF8)([^A-Za-z0-9_-]|$)' "$LOCALE_FILE"
}

is_canonical_locale_available() {
  # Une locale canonique '.UTF-8' peut être utilisable même si `locale -a` ne la
  # liste pas (glibc liste l'alias court 'fr_FR.utf8' uniquement). On vérifie
  # donc dans cet ordre :
  #   1. localectl list-locales (source systemd, contient la forme canonique)
  #   2. locale -a (fallback)
  #   3. test direct : LANG=xxx LC_ALL=xxx locale → exit 0 si utilisable
  local canonical="$1"
  if command -v localectl &>/dev/null && \
     localectl list-locales 2>/dev/null | grep -Fxq "$canonical"; then
    return 0
  fi
  if locale -a 2>/dev/null | grep -Fxq "$canonical"; then
    return 0
  fi
  LANG="$canonical" LC_ALL="$canonical" locale >/dev/null 2>&1
}

ensure_canonical_locale_available() {
  local lang_value
  lang_value="$(grep -E '^LANG=' "$LOCALE_FILE" 2>/dev/null | head -1 | sed -E 's/^LANG=//; s/"//g')"
  if [ -z "$lang_value" ]; then
    return 0
  fi
  local canonical
  canonical="$(printf '%s\n' "$lang_value" | canonicalize)"
  if is_canonical_locale_available "$canonical"; then
    echo "✓ Locale canonique '$canonical' utilisable."
    return 0
  fi
  echo "⚠ Locale canonique '$canonical' non utilisable : installation requise."
  if command -v dnf &>/dev/null; then
    local lang_short
    lang_short="$(printf '%s\n' "$canonical" | cut -d_ -f1 | tr '[:upper:]' '[:lower:]')"
    local pkg="glibc-langpack-${lang_short}"
    echo "→ Installation de $pkg via dnf..."
    sudo dnf install -y "$pkg"
  elif command -v apt-get &>/dev/null; then
    echo "→ Génération via locale-gen..."
    if ! grep -Eq "^[[:space:]]*${canonical}\b" /etc/locale.gen 2>/dev/null; then
      echo "$canonical UTF-8" | sudo tee -a /etc/locale.gen >/dev/null
    fi
    sudo locale-gen
  else
    echo "Gestionnaire de paquets non reconnu : installe manuellement la locale '$canonical'." >&2
    return 1
  fi
  if ! is_canonical_locale_available "$canonical"; then
    echo "Échec : '$canonical' toujours indisponible après installation." >&2
    return 1
  fi
}

apply_fix() {
  if [ ! -r "$LOCALE_FILE" ]; then
    echo "$LOCALE_FILE introuvable : rien à faire." >&2
    exit 1
  fi

  if ! needs_fix; then
    echo "✓ /etc/locale.conf est déjà en forme canonique. Rien à faire."
    return 0
  fi

  ensure_canonical_locale_available

  # Construit la nouvelle version en mémoire
  local new_content
  new_content="$(canonicalize < "$LOCALE_FILE")"

  echo "=== Avant ==="
  cat "$LOCALE_FILE"
  echo "=== Après ==="
  printf '%s\n' "$new_content"
  echo "---"

  # Backup horodaté + symlink stable pour rollback
  local stamped
  stamped="${BACKUP_FILE}.$(date +%Y%m%d-%H%M%S)"
  sudo cp -a "$LOCALE_FILE" "$stamped"
  sudo ln -sf "$stamped" "$BACKUP_FILE"
  echo "Backup : $stamped (alias $BACKUP_FILE)"

  # Construit les arguments KEY=VALUE pour localectl à partir du nouveau contenu
  local -a kv_args=()
  while IFS= read -r line; do
    # Skip lignes vides et commentaires
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Garde uniquement les lignes KEY=VALUE valides
    [[ "$line" =~ ^[A-Z_]+= ]] || continue
    kv_args+=("$line")
  done <<< "$new_content"

  if [ ${#kv_args[@]} -eq 0 ]; then
    echo "Aucune ligne KEY=VALUE valide trouvée." >&2
    exit 1
  fi

  echo "→ sudo localectl set-locale ${kv_args[*]}"
  sudo localectl set-locale "${kv_args[@]}"

  echo ""
  echo "✓ Fichier mis à jour."
  echo "=== Contenu final de $LOCALE_FILE ==="
  cat "$LOCALE_FILE"
  echo ""
  echo "ℹ Déconnecte-toi puis reconnecte-toi (ou reboot) pour que la session prenne la nouvelle locale."
  echo "  Vérification post-relogin :  locale  →  doit afficher LANG=...UTF-8 (avec tiret)."
}

rollback() {
  if [ ! -e "$BACKUP_FILE" ]; then
    echo "Aucun backup trouvé à $BACKUP_FILE." >&2
    exit 1
  fi
  echo "Restauration de $BACKUP_FILE → $LOCALE_FILE"
  sudo cp -a "$BACKUP_FILE" "$LOCALE_FILE"
  echo "✓ Restauré. Reboot recommandé."
}

case "${1:-}" in
  --status|status)
    print_status
    ;;
  --apply|apply)
    apply_fix
    ;;
  --rollback|rollback)
    rollback
    ;;
  ""|--help|-h|help)
    print_status
    echo ""
    if needs_fix; then
      echo "⚠ /etc/locale.conf contient des entrées non canoniques (.utf8 au lieu de .UTF-8)."
      echo "  C'est la cause du bug distrobox-init / update-locale sur les boxes Ubuntu."
      echo ""
      read -rp "Appliquer le fix maintenant ? (o/N) " ans
      if [[ "$ans" =~ ^[oO]$ ]]; then
        apply_fix
      else
        echo "Annulé. Tu peux relancer avec : $0 --apply"
      fi
    else
      echo "✓ Aucun fix nécessaire."
    fi
    ;;
  *)
    echo "Usage : $0 [--status|--apply|--rollback]" >&2
    exit 1
    ;;
esac
