[[ -n "$AGENTIC_SHELL" ]] && return

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt incappendhistory autocd beep extendedglob nomatch notify histignorespace histignoredups
bindkey -v
# End of lines configured by zsh-newuser-install

setopt AUTO_PUSHD PUSHD_IGNORE_DUPS
setopt ALWAYS_TO_END AUTO_LIST
setopt CORRECT INTERACTIVE_COMMENTS

# bindkey '^\r' autosuggest-execute-suggestion
