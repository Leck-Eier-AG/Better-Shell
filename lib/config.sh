# Better Shell — Config File Helpers
# Reads and writes a simple key=value config file at ${_BSH_DIR}/config.
# Must be sourced AFTER lib/header.sh (needs _BSH_DIR) and BEFORE lib/env.sh
# (env.sh uses _BSH_SSH_ENABLED which config may override from persisted state).

# _bsh_config_load — Read persisted settings from ${_BSH_DIR}/config into shell variables.
# Called automatically at the bottom of this file (runs when sourced at startup).
# If config file doesn't exist, returns 0 — no config is fine.
_bsh_config_load() {
  local config="${_BSH_DIR}/config"
  [[ -f "$config" ]] || return 0

  local key value
  while IFS='=' read -r key value; do
    # Skip blank lines and comment lines
    [[ -z "$key" || "$key" == \#* ]] && continue

    # Safety: only accept keys matching ^[a-zA-Z_][a-zA-Z0-9_]*$ (prevents injection)
    if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      continue
    fi

    # Map known keys to their corresponding shell variables
    case "$key" in
      enabled)         _BSH_ENABLED="$value"          ;;
      ssh_enabled)     _BSH_SSH_ENABLED="$value"      ;;
      audio_threshold) _BSH_AUDIO_THRESHOLD="$value"  ;;
      sound_pack)      _BSH_SOUND_PACK="$value"       ;;
      volume)          _BSH_VOLUME="$value"            ;;
      scaling_method)  _BSH_SCALING_METHOD="$value"   ;;
      # Unknown keys are silently ignored (forward-compatible for future settings)
    esac
  done < "$config"
}

# _bsh_config_set — Write (or update) a single key=value entry in ${_BSH_DIR}/config.
# Uses an atomic write pattern (write to .tmp.$$ then mv) to prevent corruption.
# Arguments: $1=key  $2=value
_bsh_config_set() {
  local key="$1"
  local value="$2"
  local config="${_BSH_DIR}/config"
  local tmp="${config}.tmp.$$"

  # Ensure the plugin directory exists
  mkdir -p "${_BSH_DIR}"

  if [[ -f "$config" ]]; then
    # Filter out any existing line for this key, then append the new one
    grep -v "^${key}=" "$config" > "$tmp" 2>/dev/null || true
    printf '%s=%s\n' "$key" "$value" >> "$tmp"
  else
    # Config doesn't exist — create it with just this one entry
    printf '%s=%s\n' "$key" "$value" > "$tmp"
  fi

  mv "$tmp" "$config"
}

# Auto-load persisted config on source.
# This runs after header.sh has set defaults, so config values override defaults
# but do NOT run before _BSH_DIR is set.
_bsh_config_load
