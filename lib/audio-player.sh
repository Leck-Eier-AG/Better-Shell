# Better Shell — Audio Player Engine
# Detects an available audio player at source time and provides a non-blocking
# _bsh_play_sound() function that dispatches to the detected player.
#
# Supported players (in preference order):
#   pw-play  — PipeWire (modern Linux, Wayland)
#   paplay   — PulseAudio (common Linux)
#   afplay   — macOS built-in
#   aplay    — ALSA (Linux fallback; no volume flag)
#
# If no player is found _BSH_AUDIO_TOOL remains empty and all playback is a
# silent no-op.  This is intentional — the plugin must not error on headless
# or audio-less systems.

# ---------------------------------------------------------------------------
# Default variables
# ---------------------------------------------------------------------------

# Volume level: 0-100 integer; individual player functions normalise to their
# required format.  Users can override by setting _BSH_VOLUME before sourcing.
_BSH_VOLUME="${_BSH_VOLUME:-70}"

# Detected player binary name; empty = no player available.
_BSH_AUDIO_TOOL=""

# ---------------------------------------------------------------------------
# Volume normalisation helpers
# ---------------------------------------------------------------------------

# _bsh_vol_afplay <0-100>
# Outputs a float in the range 0.00-1.00 for afplay -v
_bsh_vol_afplay() {
  awk -v v="$1" 'BEGIN { printf "%.2f\n", v / 100 }'
}

# _bsh_vol_pw <0-100>
# Outputs a float in the range 0.00-1.00 for pw-play --volume
_bsh_vol_pw() {
  awk -v v="$1" 'BEGIN { printf "%.2f\n", v / 100 }'
}

# _bsh_vol_paplay <0-100>
# Outputs an integer in the range 0-65536 for paplay --volume
_bsh_vol_paplay() {
  echo $(( $1 * 65536 / 100 ))
}

# ---------------------------------------------------------------------------
# Player detection
# ---------------------------------------------------------------------------

# _bsh_detect_audio_player
# Probe for known audio players in preference order.
# Sets _BSH_AUDIO_TOOL to the first found binary name, or "" if none exist.
# Called once at the bottom of this file (source-time, one-time detection).
_bsh_detect_audio_player() {
  local p
  for p in pw-play paplay afplay aplay; do
    if command -v "$p" >/dev/null 2>&1; then
      _BSH_AUDIO_TOOL="$p"
      return 0
    fi
  done
  _BSH_AUDIO_TOOL=""
}

# ---------------------------------------------------------------------------
# Playback
# ---------------------------------------------------------------------------

# _bsh_play_sound <file>
# Play a sound file asynchronously using the detected audio player.
# Disables monitor mode (set +m) in the PARENT shell before backgrounding so
# that "[N] Done ..." job completion messages never appear at the prompt.
# The subshell is backgrounded and disowned immediately so it does NOT block
# the next prompt from appearing. Monitor mode is re-enabled (set -m) after
# disown so the interactive session is unaffected for subsequent commands.
#
# Guards (all three trigger a silent no-op):
#   - _BSH_AUDIO_TOOL is empty (no player detected)
#   - $1 is empty
#   - $1 does not exist as a regular file
_bsh_play_sound() {
  local file="$1"

  # Guard: no player, no file path, or file does not exist
  [[ -z "${_BSH_AUDIO_TOOL:-}" ]] && return 0
  [[ -z "$file" ]]               && return 0
  [[ -f "$file" ]]               || return 0

  # Disable job control in the PARENT shell before backgrounding the subshell.
  # set +m must run in the parent — doing it inside the child is a no-op for
  # suppressing "[N] done" messages because those are printed by the parent.
  # 2>/dev/null suppresses "no job control" warnings in non-interactive contexts.
  set +m 2>/dev/null
  (
    case "$_BSH_AUDIO_TOOL" in
      pw-play)
        pw-play --volume="$(_bsh_vol_pw "${_BSH_VOLUME:-70}")" "$file" >/dev/null 2>&1
        ;;
      paplay)
        paplay --volume="$(_bsh_vol_paplay "${_BSH_VOLUME:-70}")" "$file" >/dev/null 2>&1
        ;;
      afplay)
        afplay -v "$(_bsh_vol_afplay "${_BSH_VOLUME:-70}")" "$file" >/dev/null 2>&1
        ;;
      aplay)
        aplay -q "$file" >/dev/null 2>&1
        ;;
    esac
  ) &
  disown $! 2>/dev/null
  # Re-enable job control for the interactive shell after disown
  set -m 2>/dev/null

  return 0
}

# ---------------------------------------------------------------------------
# Source-time player detection (runs once when this file is sourced)
# ---------------------------------------------------------------------------

[[ "${_BSH_ENABLED:-1}" == "1" ]] && _bsh_detect_audio_player
