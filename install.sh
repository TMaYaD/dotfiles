#! env zsh

set -e

if (( $+commands[brew] )); then
  echo "\033[0;34mSkipping Homebrew...\033[0m"
else
  echo "\033[0;34mInstalling Homebrew...\033[0m"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

function brew-install() {
  package=$1
  bin="${2:-$1}"

  if [ -d "/Applications/$bin.app" ] || (( $+commands[$bin] )); then
    echo "\033[0;34mSkipping $package...\033[0m"
  else
    echo "\033[0;34mInstalling $package...\033[0m"
    brew install $package
  fi
}

brew-install git

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

brew-install 1password "1Password 7"
brew-install google-chrome "Google Chrome"
brew-install google-cloud-sdk gcloud
brew-install iterm2 "iTerm"
brew-install karabiner-elements "Karabiner-Elements"
brew-install little-snitch "Little Snitch"
brew-install node
brew-install notion "Notion"
brew-install poetry
brew-install postico "Postico"
brew-install postman "Postman"
brew-install pyenv
brew-install rbenv
brew-install slack "Slack"
brew-install telegram "Telegram"
brew-install time-out "Time Out"
brew-install visual-studio-code "Visual Studio Code"

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
