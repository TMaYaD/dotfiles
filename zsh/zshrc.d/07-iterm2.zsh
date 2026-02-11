[[ -n "$AGENTIC_SHELL" ]] && return

# Load iterm2 shell integration
test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
