#! env zsh

set -e

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi

if [ ! -n "$DOTATOM" ]; then
  DOTATOM=~/.atom
fi

if [ -d "$DOTATOM" ]; then
  echo "\033[0;33mYou already have atom dotfiles installed.\033[0m You'll need to remove $DOTATOM if you want to install"
  exit
fi

if [ ! -d "$DOTFILES" ]; then
  echo "\033[0;34mCloning dotfiles...\033[0m"
  hash git >/dev/null 2>&1 && env git clone https://github.com/TMaYaD/dotfiles.git $DOTFILES || {
    echo "git not installed"
    exit
  }
fi

echo "\033[0;34mSymlinking atom dotfiles...\033[0m"
ln -s $DOTFILES/atom $DOTATOM

echo "\033[0;34mInstalling package-sync plugin...\033[0m"
apm install manage-packages || {
  echo "atom not installed"
  exit
}
