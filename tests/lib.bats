#!/usr/bin/env bats
# Fonctions pures de lib/. Aucune n'a besoin de distrobox ni du réseau :
# les commandes externes sont remplacées par des stubs dans le PATH de test.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$BATS_TEST_TMPDIR"
  STUB="$TMP/stub"
  mkdir -p "$STUB"
  PATH="$STUB:$PATH"
}

# --- box_exists ------------------------------------------------------------
# Historiquement le code faisait `distrobox list | grep -q "$name"`, qui matche
# aussi les préfixes. Ces tests verrouillent le comportement exact.

stub_distrobox_list() {
  cat > "$STUB/distrobox" <<EOF
#!/bin/bash
cat <<'LIST'
ID           | NAME                 | STATUS   | IMAGE
aaaa         | ubuntu_dev_go        | Exited   | img
bbbb         | ubuntu_dev_golang    | Exited   | img
LIST
EOF
  chmod +x "$STUB/distrobox"
}

@test "box_exists trouve un nom exact" {
  stub_distrobox_list
  source "$REPO/lib/common.sh"
  run box_exists ubuntu_dev_go
  [ "$status" -eq 0 ]
}

@test "box_exists ne confond pas un préfixe avec le nom complet" {
  stub_distrobox_list
  source "$REPO/lib/common.sh"
  run box_exists ubuntu_dev
  [ "$status" -ne 0 ]
}

@test "box_exists trouve aussi le nom le plus long" {
  stub_distrobox_list
  source "$REPO/lib/common.sh"
  run box_exists ubuntu_dev_golang
  [ "$status" -eq 0 ]
}

@test "box_exists renvoie faux pour une box absente" {
  stub_distrobox_list
  source "$REPO/lib/common.sh"
  run box_exists fedora_gaming
  [ "$status" -ne 0 ]
}

# --- mode non interactif ---------------------------------------------------

@test "assume_yes est faux par défaut" {
  source "$REPO/lib/common.sh"
  DISTROSCRIPT_ASSUME_YES=0
  run assume_yes
  [ "$status" -ne 0 ]
}

@test "confirm répond oui sans invite quand ASSUME_YES vaut 1" {
  source "$REPO/lib/common.sh"
  DISTROSCRIPT_ASSUME_YES=1
  run confirm "Question ?"
  [ "$status" -eq 0 ]
  [[ "$output" == *"auto: oui"* ]]
}

@test "confirm respecte une réponse négative" {
  source "$REPO/lib/common.sh"
  DISTROSCRIPT_ASSUME_YES=0
  run bash -c "source '$REPO/lib/common.sh'; DISTROSCRIPT_ASSUME_YES=0; echo n | confirm 'Q ?'"
  [ "$status" -ne 0 ]
}

@test "confirm accepte o comme réponse positive" {
  run bash -c "source '$REPO/lib/common.sh'; DISTROSCRIPT_ASSUME_YES=0; echo o | confirm 'Q ?'"
  [ "$status" -eq 0 ]
}

# --- detect_host_distro ----------------------------------------------------

@test "detect_host_distro ne pollue pas les variables de l'appelant" {
  run bash -c "
    source '$REPO/lib/common.sh'
    ID='ma-valeur'; NAME='mon-script'; VERSION='1.2.3'
    detect_host_distro >/dev/null
    echo \"\$ID|\$NAME|\$VERSION\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "ma-valeur|mon-script|1.2.3" ]
}

@test "detect_host_distro renseigne HOST_DISTRO" {
  source "$REPO/lib/common.sh"
  detect_host_distro
  [ -n "$HOST_DISTRO" ]
}

# --- manifest --------------------------------------------------------------

@test "manifest_packages_line ignore commentaires et lignes vides" {
  source "$REPO/lib/manifest.sh"
  printf '# commentaire\ngit\n\ncurl\n' > "$TMP/pkgs.txt"
  run manifest_packages_line "$TMP/pkgs.txt"
  [ "$output" = "additional_packages=git curl" ]
}

@test "manifest_packages_line ne produit rien si le fichier est absent" {
  source "$REPO/lib/manifest.sh"
  run manifest_packages_line "$TMP/absent.txt"
  [ "$output" = "" ]
}

@test "manifest_group_flags ignore un groupe inexistant" {
  source "$REPO/lib/manifest.sh"
  run manifest_group_flags groupe-qui-nexiste-pas
  [ "$output" = "" ]
}

# --- fetch -----------------------------------------------------------------

@test "github_latest_tag retombe sur le repli quand l'API échoue" {
  cat > "$STUB/curl" <<'EOF'
#!/bin/bash
exit 22
EOF
  chmod +x "$STUB/curl"
  source "$REPO/lib/fetch.sh"
  # stderr est écarté : `run` le fusionnerait avec stdout, or la fonction y
  # écrit son avertissement de repli. Seule la valeur renvoyée nous intéresse.
  run bash -c "source '$REPO/lib/fetch.sh'; github_latest_tag proprietaire/depot v9.9.9 2>/dev/null"
  [ "$status" -eq 0 ]
  [ "$output" = "v9.9.9" ]
}

@test "github_latest_tag ne fait pas échouer un script sous set -e" {
  cat > "$STUB/curl" <<'EOF'
#!/bin/bash
exit 22
EOF
  chmod +x "$STUB/curl"
  run bash -c "
    set -euo pipefail
    source '$REPO/lib/fetch.sh'
    PATH='$STUB:\$PATH'
    v=\"\$(github_latest_tag a/b v1.0.0 2>/dev/null)\"
    echo \"survecu:\$v\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"survecu:v1.0.0"* ]]
}

@test "download_file rejette et supprime un fichier au mauvais SHA-256" {
  source "$REPO/lib/fetch.sh"
  cat > "$STUB/curl" <<EOF
#!/bin/bash
# écrit un contenu connu dans la destination passée après -o
while [ \$# -gt 0 ]; do
  [ "\$1" = "-o" ] && { printf 'contenu' > "\$2"; exit 0; }
  shift
done
exit 1
EOF
  chmod +x "$STUB/curl"
  run download_file "http://exemple/x" "$TMP/out.bin" \
    "0000000000000000000000000000000000000000000000000000000000000000"
  [ "$status" -ne 0 ]
  [ ! -f "$TMP/out.bin" ]
}

@test "download_file accepte un SHA-256 correct" {
  source "$REPO/lib/fetch.sh"
  cat > "$STUB/curl" <<EOF
#!/bin/bash
while [ \$# -gt 0 ]; do
  [ "\$1" = "-o" ] && { printf 'contenu' > "\$2"; exit 0; }
  shift
done
exit 1
EOF
  chmod +x "$STUB/curl"
  sha="$(printf 'contenu' | sha256sum | awk '{print $1}')"
  run download_file "http://exemple/x" "$TMP/ok.bin" "$sha"
  [ "$status" -eq 0 ]
  [ -f "$TMP/ok.bin" ]
}
