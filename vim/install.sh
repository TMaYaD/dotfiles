#! env zsh

set -e

if [ ! -n "$DOTVIM" ]; then
  DOTVIM=~/.vim
fi

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi

if [ -d "$DOTVIM" ]; then
  echo "\033[0;33mYou already have vim dotfiles installed.\033[0m You'll need to remove $DOTVIM if you want to install"
  exit
fi

if [ ! -d "$DOTFILES" ]; then
  echo "\033[0;34mCloning Vim dotfiles...\033[0m"
  hash git >/dev/null 2>&1 && env git clone https://github.com/TMaYaD/dotfiles.git $DOTFILES || {
    echo "git not installed"
    exit
  }
fi
ln -s $DOTFILES/vim $DOTVIM

echo "\033[0;34mLooking for an existing vimrc...\033[0m"
if [ -f ~/.vimrc ] || [ -h ~/.vimrc ]; then
  echo "\033[0;33mFound ~/.vimrc.\033[0m \033[0;32mBacking up to ~/.vimrc.pre-dotvim\033[0m";
  mv ~/.vimrc ~/.vimrc.pre-dotvim;
fi

echo "\033[0;34mLooking for an existing gvimrc...\033[0m"
if [ -f ~/.gvimrc ] || [ -h ~/.gvimrc ]; then
  echo "\033[0;33mFound ~/.gvimrc.\033[0m \033[0;32mBacking up to ~/.gvimrc.pre-dotvim\033[0m";
  mv ~/.gvimrc ~/.gvimrc.pre-dotvim;
fi

echo "\033[0;34mSymlinking rc files...\033[0m"
ln -s $DOTVIM/vimrc ~/.vimrc
ln -s $DOTVIM/gvimrc ~/.gvimrc

echo "\033[0;34mInstalling bundles...\033[0m"
pushd $DOTVIM
  git clone https://github.com/gmarik/vundle.git $DOTVIM/bundle/vundle
  vim -u bundles.vim +BundleInstall +qall
popd
