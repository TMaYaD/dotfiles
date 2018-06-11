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

echo "\033[0;34mLooking for an existing zshrc...\033[0m"
if [ -f ~/.zshrc ] || [ -h ~/.zshrc ]; then
  echo "\033[0;33mFound ~/.zshrc.\033[0m \033[0;32mBacking up to ~/.zshrc.pre-dotzsh\033[0m";
  mv ~/.zshrc ~/.zshrc.pre-dotzsh;
fi

echo "\033[0;34mLooking for an existing zshenv...\033[0m"
if [ -f ~/.zshenv ] || [ -h ~/.zshenv ]; then
  echo "\033[0;33mFound ~/.zshenv.\033[0m \033[0;32mBacking up to ~/.zshenv.pre-dotzsh\033[0m";
  mv ~/.zshenv ~/.zshenv.pre-dotzsh;
fi

echo "\033[0;34mSymlinking rc files...\033[0m"
ln -s $DOTVIM/zsh/zshrc ~/.zshrc
ln -s $DOTVIM/zsh/zshenv ~/.zshenv
