#!/usr/bin/env bats
# Fonctions pures des scripts de locale. Elles sont testables parce que les
# scripts ne lancent leur dispatch que s'ils sont exécutés (garde BASH_SOURCE),
# et parce que LOCALE_FILE est surchargeable.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$BATS_TEST_TMPDIR"
}

@test "canonicalize convertit .utf8 en .UTF-8" {
  source "$REPO/fix_locale.sh"
  run bash -c "printf 'LANG=fr_FR.utf8\n' | { $(declare -f canonicalize); canonicalize; }"
  [ "$status" -eq 0 ]
  [ "$output" = "LANG=fr_FR.UTF-8" ]
}

@test "canonicalize gère la casse .UTF8" {
  source "$REPO/fix_locale.sh"
  result="$(printf 'LC_TIME=en_US.UTF8\n' | canonicalize)"
  [ "$result" = "LC_TIME=en_US.UTF-8" ]
}

@test "canonicalize laisse intacte une valeur déjà canonique" {
  source "$REPO/fix_locale.sh"
  result="$(printf 'LANG=fr_FR.UTF-8\n' | canonicalize)"
  [ "$result" = "LANG=fr_FR.UTF-8" ]
}

@test "canonicalize traite plusieurs lignes" {
  source "$REPO/fix_locale.sh"
  result="$(printf 'LANG=fr_FR.utf8\nLC_ALL=fr_FR.utf8\n' | canonicalize)"
  [ "$result" = "$(printf 'LANG=fr_FR.UTF-8\nLC_ALL=fr_FR.UTF-8')" ]
}

@test "needs_fix détecte un fichier non canonique" {
  printf 'LANG=fr_FR.utf8\n' > "$TMP/locale.conf"
  LOCALE_FILE="$TMP/locale.conf" source "$REPO/fix_locale.sh"
  LOCALE_FILE="$TMP/locale.conf"
  run needs_fix
  [ "$status" -eq 0 ]
}

@test "needs_fix ignore un fichier déjà canonique" {
  printf 'LANG=fr_FR.UTF-8\n' > "$TMP/locale.conf"
  LOCALE_FILE="$TMP/locale.conf" source "$REPO/fix_locale.sh"
  LOCALE_FILE="$TMP/locale.conf"
  run needs_fix
  [ "$status" -ne 0 ]
}

@test "needs_fix renvoie faux si le fichier est absent" {
  LOCALE_FILE="$TMP/inexistant.conf" source "$REPO/fix_locale.sh"
  LOCALE_FILE="$TMP/inexistant.conf"
  run needs_fix
  [ "$status" -ne 0 ]
}

@test "--help n'exécute aucune action et ne touche à rien" {
  run "$REPO/fix_locale.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" != *"État actuel"* ]]
}

@test "revert_locale.sh --help n'exécute aucune action" {
  run "$REPO/revert_locale.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" != *"Backups disponibles"* ]]
}

@test "une option inconnue est rejetée" {
  run "$REPO/fix_locale.sh" --nawak
  [ "$status" -ne 0 ]
}
