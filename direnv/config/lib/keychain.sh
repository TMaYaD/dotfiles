# direnv helper: fetch secrets from macOS Keychain.
#
# Auto-loaded by direnv from ~/.config/direnv/lib/*.sh, so every .envrc
# can call keychain_env without sourcing anything explicitly.
#
# Usage inside a project .envrc:
#   keychain_env OPENAI_API_KEY project-x/openai
#   keychain_env DB_PASSWORD    project-x/db    someuser
#
# Store a secret (see also the `keychain-set` shell helper):
#   security add-generic-password -s project-x/openai -a "$USER" -w 'sk-...' -U

keychain_env() {
  local var="$1" service="$2" account="${3:-$USER}"

  if [[ -z "$var" || -z "$service" ]]; then
    log_error "keychain_env: usage: keychain_env VAR_NAME service [account]"
    return 1
  fi

  if ! command -v security >/dev/null 2>&1; then
    log_error "keychain_env: 'security' not found (macOS Keychain only)"
    return 1
  fi

  local value
  if ! value=$(security find-generic-password -s "$service" -a "$account" -w 2>/dev/null); then
    log_error "keychain_env: no Keychain entry for service='$service' account='$account'"
    return 1
  fi

  export "$var=$value"
}

# Like keychain_env, but if the secret is missing prompt for it and store it,
# then export. Only prompts when stdin is a tty — in non-interactive contexts
# (editor direnv plugins, CI) it fails with a clear error instead of hanging.
#
# Usage: keychain_env_or_set VAR_NAME service [account]
keychain_env_or_set() {
  local var="$1" service="$2" account="${3:-$USER}"

  if [[ -z "$var" || -z "$service" ]]; then
    log_error "keychain_env_or_set: usage: keychain_env_or_set VAR_NAME service [account]"
    return 1
  fi

  if ! command -v security >/dev/null 2>&1; then
    log_error "keychain_env_or_set: 'security' not found (macOS Keychain only)"
    return 1
  fi

  local value
  if value=$(security find-generic-password -s "$service" -a "$account" -w 2>/dev/null); then
    export "$var=$value"
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log_error "keychain_env_or_set: no entry for service='$service' and stdin is not a tty; set it with: keychain-set '$service'"
    return 1
  fi

  log_status "keychain_env_or_set: no Keychain entry for '$service' — prompting to create one"
  printf 'Value for %s (hidden): ' "$service" >&2
  IFS= read -rs value
  printf '\n' >&2

  if [[ -z "$value" ]]; then
    log_error "keychain_env_or_set: empty value, not storing"
    return 1
  fi

  if ! security add-generic-password -s "$service" -a "$account" -w "$value" -U >/dev/null; then
    log_error "keychain_env_or_set: failed to store secret in Keychain"
    return 1
  fi

  export "$var=$value"
}
