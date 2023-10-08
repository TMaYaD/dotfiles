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


echo "\033[0;34mLooking for an existing Brewfile...\033[0m"
if [ -f ~/.Brewfile ] || [ -h ~/.Brewfile ]; then
  echo "\033[0;33mFound ~/.Brewfile.\033[0m \033[0;32mBacking up to ~/.Brewfile.pre-dot\033[0m";
  mv ~/.Brewfile ~/.Brewfile.pre-dot;
fi

echo "\033[0;34mSymlinking Brewfile...\033[0m"
ln -s $DOTFILES/Brewfile ~/.Brewfile

brew bundle --global

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


# Disable Apples nagging "Start using iCloud" notification badge in System Preferences
defaults read com.apple.systempreferences AttentionPrefBundleIDs && \
  defaults delete com.apple.systempreferences AttentionPrefBundleIDs

