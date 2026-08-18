#!/bin/bash
# Helpers à sourcer dans les post_install.sh des boxes Ubuntu.
# Évite la duplication des blocs PS1, alias et configuration Zsh.
#
# À copier dans le HOME_DIR de la box par install.sh, puis dans
# post_install.sh : source ~/shell_setup.sh

# Crée ~/.local/bin, l'ajoute au PATH (.bashrc + session courante).
# Expose la variable LOCAL_BIN pour le caller.
setup_local_bin() {
  export LOCAL_BIN="$HOME/.local/bin"
  mkdir -p "$LOCAL_BIN"
  if ! grep -q 'HOME/.local/bin' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  fi
  export PATH="$LOCAL_BIN:$PATH"
}

# Ajoute le prompt 📦 et l'alias `code --no-sandbox` dans .bashrc (idempotent).
setup_prompt_and_aliases() {
  if ! grep -q 'PS1=.*📦' ~/.bashrc 2>/dev/null; then
    echo 'export PS1="📦[\u@\h \W]\\$ "' >> ~/.bashrc
  fi
  if ! grep -q "alias code=" ~/.bashrc 2>/dev/null; then
    echo "alias code='code --no-sandbox'" >> ~/.bashrc
  fi
}

# Marqueurs délimitant la section gérée par DistroScript dans ~/.zshrc.
# Tout ce qui est en dehors appartient à l'utilisateur et n'est jamais touché.
_ZSHRC_BEGIN='# >>> DistroScript >>>'
_ZSHRC_END='# <<< DistroScript <<<'

# Crée ou MET À JOUR ~/.zshrc, puis bascule le shell par défaut sur zsh.
# Lit un body custom depuis stdin (héredoc) ; les alias et le prompt de base
# sont ajoutés à la suite.
#
# La section gérée est délimitée par des marqueurs et réécrite à chaque appel :
# relancer un post_install met donc la configuration à jour. L'ancienne version
# sortait si ~/.zshrc existait déjà, si bien qu'aucune modification n'était
# jamais reprise — un changement de body était silencieusement perdu.
#
# Usage :
#   setup_zsh_with_body <<'EOF'
#   export PYENV_ROOT="$HOME/.pyenv"
#   EOF
#
#   # Sans body custom :
#   setup_zsh_with_body </dev/null
setup_zsh_with_body() {
  command -v zsh &>/dev/null || return 0

  local body managed
  body="$(cat)"

  managed="$(printf '%s\n%s\n\nalias code=%s\nalias ll=%s\nexport PROMPT=%s\n%s\n' \
    "$_ZSHRC_BEGIN" \
    "$body" \
    "'code --no-sandbox'" \
    "'ls -lah'" \
    "'[%n@%m %1~]%# '" \
    "$_ZSHRC_END")"

  if [ -f ~/.zshrc ] && grep -qF "$_ZSHRC_BEGIN" ~/.zshrc; then
    # Remplace la section gérée, en préservant le reste du fichier.
    local tmp
    tmp="$(mktemp)"
    awk -v begin="$_ZSHRC_BEGIN" -v end="$_ZSHRC_END" -v repl="$managed" '
      $0 == begin { print repl; skip = 1; next }
      $0 == end   { skip = 0; next }
      !skip       { print }
    ' ~/.zshrc > "$tmp"
    mv "$tmp" ~/.zshrc
  else
    # Première configuration : la section gérée est ajoutée à la fin d'un
    # éventuel .zshrc existant, dont le contenu est conservé.
    printf '%s\n' "$managed" >> ~/.zshrc
  fi

  chsh -s "$(command -v zsh)" 2>/dev/null || true
}
