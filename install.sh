#! env zsh

set -e

if (( $+commands[brew] )); then
  echo "\033[0;34mSkipping Homebrew...\033[0m"
else
  echo "\033[0;34mInstalling Homebrew...\033[0m"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

eval "$(brew shellenv)"

(( $+commands[git] )) || brew install git

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

source $DOTFILES/helpers.func.zsh

install_config $DOTFILES/Brewfile ~/.Brewfile

brew bundle --global

# Run individual installers
for installer in $DOTFILES/*/install.sh
do
  directory=$(dirname $installer)
  package=$(basename $directory)

  if [[ -x "$installer" ]]
  then
    echo "\033[0;34msetting up $package...\033[0m"
    pushd $directory
    ./install.sh
    popd
  else
    echo "\033[0;34mSkipping $package...\033[0m"
  fi
done
