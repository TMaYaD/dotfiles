#! env zsh

set -e

if (( $+commands[brew] )); then
  echo "\033[0;34mSkipping Homebrew...\033[0m"
else
  echo "\033[0;34mInstalling Homebrew...\033[0m"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

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

function cask-install() {
  if [ -d "/Applications/$1.app" ]; then
    echo "\033[0;34mSkipping $1...\033[0m"
  else
    echo "\033[0;34mInstalling $1...\033[0m"
    brew cask install $2
  fi
}

function brew-install() {
  if (( $+commands[$1] )); then
    echo "\033[0;34mSkipping $1...\033[0m"
  else
    echo "\033[0;34mInstalling $1...\033[0m"
    brew install $2
  fi
}

cask-install "iTerm" iterm2
cask-install "Karabiner-Elements" karabiner-elements
cask-install "Time Out" time-out
cask-install "Visual Studio Code" visual-studio-code
cask-install "Little Snitch Configuration" little-snitch
cask-install "Google Chrome" google-chrome
cask-install "1Password 7" 1password
cask-install "Slack" slack
cask-install "Notion" notion

brew-install rbenv rbenv
brew-install pyenv pyenv
brew-install poetry poetry
brew-install gcloud google-cloud-sdk



