# Better Shell — Audio Trigger Logic
# Evaluates whether audio feedback should play after each command, determines
# the event type and intensity, resolves the sound file, and dispatches to
# _bsh_play_sound (defined in audio-player.sh, sourced before this file).
#
# Called from _bsh_precmd in lib/hooks.sh.

# ---------------------------------------------------------------------------
# Default variables
# ---------------------------------------------------------------------------

# Threshold in seconds.  SECONDS is an integer in both bash and zsh, so sub-
# second precision is unavailable.  1 second is as close as possible to the
# 500 ms user intent: a duration of 0 (command completed within the same
# second it started) is skipped; 1+ second commands play audio.
_BSH_AUDIO_THRESHOLD="${_BSH_AUDIO_THRESHOLD:-1}"

# Sound pack name; resolves to ${_BSH_DIR}/sounds/${_BSH_SOUND_PACK}/
_BSH_SOUND_PACK="${_BSH_SOUND_PACK:-meme}"

# Intensity scaling method: "duration" (default) or "command-type"
_BSH_SCALING_METHOD="${_BSH_SCALING_METHOD:-duration}"

# Stderr detection: opt-in (default OFF).  When enabled, _bsh_preexec redirects
# stderr through tee so _bsh_precmd can detect if the command produced stderr
# output and trigger a warning event instead of success.
# Users enable via: export _BSH_STDERR_DETECT=1  or  stderr_detect=1 in config.
_BSH_STDERR_DETECT="${_BSH_STDERR_DETECT:-0}"

# ---------------------------------------------------------------------------
# Blacklist / whitelist arrays
# ---------------------------------------------------------------------------

# Commands matching any pattern are silenced (threshold and blacklist skipped).
# Patterns are ERE; do NOT quote when used in [[ =~ ]] (quoting disables regex).
_BSH_BLACKLIST_PATTERNS=(
  "^vim$"    "^nvim$"   "^nano$"   "^emacs$"  "^vi$"
  "^man$"    "^less$"   "^more$"   "^watch$"  "^top$"
  "^htop$"   "^python"  "^node$"   "^irb$"    "^psql$"
  "^mysql$"  "^ssh$"
)

# Commands matching any pattern bypass threshold AND blacklist checks.
# Empty by default; users populate in their config.
_BSH_WHITELIST_PATTERNS=()

# ---------------------------------------------------------------------------
# Helpers: blacklist / whitelist matching
# ---------------------------------------------------------------------------

# _bsh_is_blacklisted <cmd_name>
# Returns 0 (true) if cmd_name matches any pattern in _BSH_BLACKLIST_PATTERNS.
_bsh_is_blacklisted() {
  local cmd_name="$1"
  local pattern
  for pattern in "${_BSH_BLACKLIST_PATTERNS[@]}"; do
    # Do NOT quote $pattern — quoting disables ERE matching in bash/zsh
    [[ "$cmd_name" =~ $pattern ]] && return 0
  done
  return 1
}

# _bsh_in_whitelist <cmd_name>
# Returns 0 (true) if cmd_name matches any pattern in _BSH_WHITELIST_PATTERNS.
# Empty array always returns 1 (nothing whitelisted).
_bsh_in_whitelist() {
  local cmd_name="$1"
  local pattern
  for pattern in "${_BSH_WHITELIST_PATTERNS[@]}"; do
    [[ "$cmd_name" =~ $pattern ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Intensity calculation
# ---------------------------------------------------------------------------

# _bsh_get_intensity <duration_seconds>
# Duration-based bucketing:
#   < 5 s  → light
#   5-30 s → medium
#   > 30 s → heavy
_bsh_get_intensity() {
  local duration="$1"
  if [[ "$duration" -lt 5 ]]; then
    echo "light"
  elif [[ "$duration" -le 30 ]]; then
    echo "medium"
  else
    echo "heavy"
  fi
}

# ---------------------------------------------------------------------------
# Sound file resolution
# ---------------------------------------------------------------------------

# _bsh_resolve_sound <event> <intensity>
# Searches for a sound file in preference order:
#   1. User drop-in:    ~/.config/better-shell/sounds/<event>/
#   2. User custom pack: ~/.config/better-shell/packs/<_BSH_SOUND_PACK>/<event>/
#   3. Bundled pack:    ${_BSH_DIR}/sounds/${_BSH_SOUND_PACK}/<event>/
# Within each directory, tries <intensity>.wav, <intensity>.mp3, then any
# glob match for <intensity>.*.
# Echoes the resolved file path, or empty string if none found.
_bsh_resolve_sound() {
  local event="$1"
  local intensity="$2"
  local f

  local -a search_dirs=(
    "${HOME}/.config/better-shell/sounds/${event}"
    "${HOME}/.config/better-shell/packs/${_BSH_SOUND_PACK}/${event}"
    "${_BSH_DIR}/sounds/${_BSH_SOUND_PACK}/${event}"
  )

  local dir
  for dir in "${search_dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    for f in "${dir}/${intensity}.wav" "${dir}/${intensity}.mp3" "${dir}/${intensity}".*; do
      [[ -f "$f" ]] && echo "$f" && return 0
    done
  done

  echo ""
}

# ---------------------------------------------------------------------------
# Config hot reload — checks mtime on each _bsh_audio_trigger call
# ---------------------------------------------------------------------------

# _bsh_audio_config_check
# Reloads ${_BSH_DIR}/config if its modification time has changed since the
# last call.  Called at the top of _bsh_audio_trigger so config edits take
# effect immediately without requiring the user to re-source the plugin.
_bsh_audio_config_check() {
  local config="${_BSH_DIR}/config"
  [[ -f "$config" ]] || return 0
  local current_mtime
  # stat -c %Y (GNU/Linux) with fallback to stat -f %m (macOS/BSD)
  current_mtime=$(stat -c %Y "$config" 2>/dev/null || stat -f %m "$config" 2>/dev/null || echo "0")
  [[ "$current_mtime" == "${_BSH_CONFIG_MTIME:-}" ]] && return 0
  _BSH_CONFIG_MTIME="$current_mtime"
  _bsh_config_load
}

# ---------------------------------------------------------------------------
# Main audio trigger — called from _bsh_precmd
# ---------------------------------------------------------------------------

# _bsh_audio_trigger
# Reads global state variables set by the hook infrastructure:
#   _BSH_AUDIO_TOOL    — detected player (empty = silent)
#   _BSH_LAST_CMD      — command string typed by the user
#   _BSH_CMD_DURATION  — elapsed seconds for the last command
#   _BSH_LAST_EXIT     — exit code of the last command
#   _BSH_LAST_STDERR   — (optional) stderr indicator; non-empty → warning event
#
# Decision flow:
#   1. No player → return (silent)
#   2. Whitelist match → skip threshold & blacklist, play
#   3. Duration below threshold → return (too fast)
#   4. Blacklist match → return (interactive/editor command)
#   5. Determine event: error | warning | success
#   6. Resolve intensity from duration
#   7. Resolve sound file → play
_bsh_audio_trigger() {
  # Hot reload: pick up config file changes without re-sourcing
  _bsh_audio_config_check

  # Guard: no audio player means total silence
  [[ -z "${_BSH_AUDIO_TOOL:-}" ]] && return 0

  # Extract just the command name (first word, no args)
  local cmd_name="${_BSH_LAST_CMD%% *}"

  # Whitelist overrides threshold and blacklist
  if ! _bsh_in_whitelist "$cmd_name"; then
    # Threshold check: skip commands that completed in under the threshold
    [[ "${_BSH_CMD_DURATION:-0}" -lt "${_BSH_AUDIO_THRESHOLD:-1}" ]] && return 0

    # Blacklist check: skip interactive/editor/REPL commands
    _bsh_is_blacklisted "$cmd_name" && return 0
  fi

  # Determine event type based on exit code (and optional stderr indicator)
  local event
  if [[ "${_BSH_LAST_EXIT:-0}" -ne 0 ]]; then
    event="error"
  elif [[ -n "${_BSH_LAST_STDERR:-}" ]]; then
    event="warning"
  else
    event="success"
  fi

  # Calculate intensity from command duration
  local intensity
  intensity="$(_bsh_get_intensity "${_BSH_CMD_DURATION:-0}")"

  # Resolve the sound file path
  local sound_file
  sound_file="$(_bsh_resolve_sound "$event" "$intensity")"

  # Play (no-op if sound_file is empty — _bsh_play_sound guards on empty/missing)
  _bsh_play_sound "$sound_file"
}
