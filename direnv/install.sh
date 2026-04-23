#! env zsh

set -e

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi
source $DOTFILES/helpers.func.zsh

# install_config symlinks source -> destination, backing up any existing
# destination into $DOTFILES/backups/. ~/.config must exist first.
mkdir -p ~/.config

install_config $DOTFILES/direnv/config ~/.config/direnv
