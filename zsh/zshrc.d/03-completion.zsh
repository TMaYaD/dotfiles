[[ -n "$AGENTIC_SHELL" ]] && return

# The following lines were added by compinstall
zstyle :compinstall filename '/home/phoenix/.zshrc'

autoload -Uz compinit && compinit -u

# End of lines added by compinstall

zstyle ':completion:*' matcher-list 'm:{a-zA-Z-_}={A-Za-z_-}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
