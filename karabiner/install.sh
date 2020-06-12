#! env zsh

set -e

if [ ! -n "$DOTFILES" ]; then
  DOTFILES=~/.dotfiles
fi

if [ ! -d "$DOTFILES" ]; then
  echo "\033[0;34mCloning dotfiles...\033[0m"
  hash git >/dev/null 2>&1 && env git clone https://github.com/TMaYaD/dotfiles.git $DOTFILES || {
    echo "git not installed"
    exit
  }
fi

echo "\033[0;34mLooking for an existing karabiner config...\033[0m"
if [ -f ~/.config/karabiner ] || [ -h ~/.config/karabiner ]; then
  echo "\033[0;33mFound ~/.config/karabiner.\033[0m \033[0;32mBacking up to ~/.config/karabiner.pre-dotzsh\033[0m";
  mv ~/.config/karabiner ~/.config/karabiner.pre-dotzsh;
fi

echo "\033[0;34mSymlinking rc files...\033[0m"
ln -s $DOTFILES/karabiner ~/.config/karabiner
