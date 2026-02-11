source "$(brew --prefix)/share/google-cloud-sdk/path.zsh.inc"

[[ -n "$AGENTIC_SHELL" ]] && return

source "$(brew --prefix)/share/google-cloud-sdk/completion.zsh.inc"
