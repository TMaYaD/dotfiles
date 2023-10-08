#! env zsh

set -e

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi
source $DOTFILES/helpers.func.zsh

install_config $DOTFILES/zsh/zshrc ~/.zshrc
install_config $DOTFILES/zsh/zshenv ~/.zshenv
install_config $DOTFILES/zsh/zsh_plugins.txt ~/.zsh_plugins.txt
