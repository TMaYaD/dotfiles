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

echo "\033[0;34mLooking for an existing git config...\033[0m"
if [ -f ~/.gitconfig ] || [ -h ~/.gitconfig ]; then
  echo "\033[0;33mFound ~/.gitconfig\033[0m \033[0;32mBacking up to ~/.gitconfig.pre-dotfiles\033[0m";
  mv ~/.gitconfig ~/.gitconfig.pre-dotzsh;
fi

echo "\033[0;34mSymlinking rc files...\033[0m"
ln -s $DOTFILES/git/gitconfig ~/.gitconfig
