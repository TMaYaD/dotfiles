#! env zsh

set -e

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi
source $DOTFILES/helpers.func.zsh

install_config $DOTFILES/karabiner ~/.config/karabiner
