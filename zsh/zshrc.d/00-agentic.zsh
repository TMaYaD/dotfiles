[[ -n "$AGENTIC_SHELL" ]] || return

export PS1='$ '
unset PROMPT_COMMAND
unset precmd_functions
unset preexec_functions
