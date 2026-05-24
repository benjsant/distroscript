#!/bin/bash
# Restaure /etc/locale.conf depuis un backup créé par fix_locale.sh.
# Liste les backups disponibles et propose une restauration interactive.
#
# Usage :
#   ./revert_locale.sh            # mode interactif, propose les backups disponibles
#   ./revert_locale.sh --latest   # restaure directement le dernier backup
#   ./revert_locale.sh --list     # affiche les backups sans rien restaurer

set -euo pipefail

LOCALE_FILE="/etc/locale.conf"
BACKUP_GLOB="/etc/locale.conf.bak.distroscript.*"
BACKUP_SYMLINK="/etc/locale.conf.bak.distroscript"

list_backups() {
  # Renvoie une liste triée du plus récent au plus ancien
  # shellcheck disable=SC2086
  ls -1t $BACKUP_GLOB 2>/dev/null
}

show_backups() {
  echo "=== Backups disponibles ==="
  local backups
  backups="$(list_backups)"
  if [ -z "$backups" ]; then
    echo "Aucun backup trouvé. fix_locale.sh n'a probablement jamais été lancé."
    return 1
  fi
  local i=1
  while IFS= read -r b; do
    local size mtime
    size="$(stat -c %s "$b" 2>/dev/null || echo "?")"
    mtime="$(stat -c %y "$b" 2>/dev/null | cut -d. -f1 || echo "?")"
    printf "%2d) %s  (%s octets, %s)\n" "$i" "$b" "$size" "$mtime"
    i=$((i + 1))
  done <<< "$backups"
  echo ""
  if [ -L "$BACKUP_SYMLINK" ]; then
    echo "Alias 'dernier' (symlink) : $BACKUP_SYMLINK → $(readlink -f "$BACKUP_SYMLINK")"
  fi
  return 0
}

show_current() {
  echo "=== /etc/locale.conf actuel ==="
  if [ -r "$LOCALE_FILE" ]; then
    cat "$LOCALE_FILE"
  else
    echo "(introuvable)"
  fi
}

restore_file() {
  local source="$1"
  if [ ! -f "$source" ]; then
    echo "Backup introuvable : $source" >&2
    exit 1
  fi
  echo ""
  echo "=== Diff entre $LOCALE_FILE et $source ==="
  diff -u "$LOCALE_FILE" "$source" || true
  echo ""
  read -rp "Restaurer ce backup vers $LOCALE_FILE ? (o/N) " confirm
  if [[ ! "$confirm" =~ ^[oO]$ ]]; then
    echo "Annulé."
    exit 0
  fi
  # Petit méta-backup de l'actuel avant restore, au cas où
  local pre_restore="${LOCALE_FILE}.before-revert.$(date +%Y%m%d-%H%M%S)"
  sudo cp -a "$LOCALE_FILE" "$pre_restore"
  echo "État courant sauvegardé dans : $pre_restore"
  sudo cp -a "$source" "$LOCALE_FILE"
  echo "✓ Restauré depuis $source"
  echo ""
  echo "=== Nouveau contenu de $LOCALE_FILE ==="
  cat "$LOCALE_FILE"
  echo ""
  echo "ℹ Déconnecte-toi puis reconnecte-toi (ou reboot) pour que la session"
  echo "  prenne la locale restaurée."
}

case "${1:-}" in
  --list|list)
    show_backups || exit 1
    ;;
  --latest|latest)
    target="$(list_backups | head -1)"
    if [ -z "$target" ]; then
      echo "Aucun backup à restaurer." >&2
      exit 1
    fi
    show_current
    echo ""
    restore_file "$target"
    ;;
  ""|--help|-h|help)
    show_current
    echo ""
    if ! show_backups; then
      exit 1
    fi
    echo ""
    read -rp "Numéro du backup à restaurer (Entrée = le plus récent, q = quitter) : " choice
    case "$choice" in
      q|Q) exit 0 ;;
      "")  target="$(list_backups | head -1)" ;;
      *[!0-9]*)
        echo "Choix invalide." >&2
        exit 1
        ;;
      *)
        target="$(list_backups | sed -n "${choice}p")"
        if [ -z "$target" ]; then
          echo "Numéro hors plage." >&2
          exit 1
        fi
        ;;
    esac
    restore_file "$target"
    ;;
  *)
    echo "Usage : $0 [--list|--latest]" >&2
    exit 1
    ;;
esac
