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

# Crée ~/.zshrc + chsh vers zsh.
# Lit un body custom depuis stdin (héredoc) et l'ajoute en tête, puis appende
# les alias/prompt de base. No-op si zsh absent ou ~/.zshrc existe déjà.
#
# Usage :
#   setup_zsh_with_body <<'EOF'
#   export PYENV_ROOT="$HOME/.pyenv"
#   export PATH="$PYENV_ROOT/bin:$PATH"
#   EOF
#
#   # Sans body custom :
#   setup_zsh_with_body </dev/null
setup_zsh_with_body() {
  command -v zsh &>/dev/null || return 0
  [ -f ~/.zshrc ] && return 0

  # Le body custom du caller (peut être vide)
  cat > ~/.zshrc

  # Append base : alias et prompt zsh
  cat >> ~/.zshrc <<'BASE'

alias code='code --no-sandbox'
alias ll='ls -lah'
export PROMPT='[%n@%m %1~]%# '
BASE

  chsh -s "$(which zsh)" 2>/dev/null || true
}
