# Load direnv
if type direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# Store a secret in macOS Keychain for use with `keychain_env` in .envrc files.
# Usage: keychain-set project-x/openai 'sk-...'         # value inline
#        keychain-set project-x/db                      # prompts (hidden)
#        keychain-set project-x/db '' alice@example.com # custom account
keychain-set() {
  local service="$1" value="$2" account="${3:-$USER}"
  if [[ -z "$service" ]]; then
    echo "usage: keychain-set service [value] [account]" >&2
    return 1
  fi
  if [[ -z "$value" ]]; then
    printf 'Value for %s (hidden): ' "$service" >&2
    read -rs value
    printf '\n' >&2
  fi
  security add-generic-password -s "$service" -a "$account" -w "$value" -U
}
