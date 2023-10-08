#! env zsh

set -e

if [ ! -n "$DOTVIM" ]; then
  DOTVIM=~/.vim
fi

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi
source $DOTFILES/helpers.func.zsh

if [ -d "$DOTVIM" ]; then
  echo "\033[0;33mYou already have vim dotfiles installed.\033[0m You'll need to remove $DOTVIM if you want to install"
  exit
fi

install_config $DOTFILES/vim $DOTVIM
install_config $DOTVIM/vimrc ~/.vimrc
install_config $DOTVIM/gvimrc ~/.gvimrc

echo "\033[0;34mInstalling bundles...\033[0m"
pushd $DOTVIM
  git clone https://github.com/gmarik/vundle.git $DOTVIM/bundle/vundle
  vim -u bundles.vim +BundleInstall +qall
popd
