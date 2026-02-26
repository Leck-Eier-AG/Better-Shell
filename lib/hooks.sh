# Better Shell — Hook Implementations
# Defines _bsh_preexec and _bsh_precmd, then registers them with the appropriate
# shell hook mechanism (bash-preexec arrays for bash, add-zsh-hook for zsh).

# _bsh_preexec — called before each interactive command executes.
# $1: the command string typed by the user (provided by bash-preexec and zsh).
# Records the command start time and the command string.
_bsh_preexec() {
  # zsh: reset to known-good zsh option state (safe against frameworks that set unusual options)
  # This is a no-op in bash (emulate is a zsh builtin).
  # Note: emulate does not reset $? so it is safe here before the guard.
  [[ -n "${ZSH_VERSION:-}" ]] && emulate -L zsh

  # Fast path: if plugin is disabled, do nothing.
  [[ $_BSH_ENABLED == 1 ]] || return 0

  # Record when the command started (SECONDS is a bash/zsh builtin; no subshell needed)
  _BSH_CMD_START_TIME=$SECONDS

  # Record the command string ($1 is passed by both bash-preexec and zsh native hook)
  _BSH_LAST_CMD="${1:-}"
}

# _bsh_precmd — called after each interactive command completes (before the next prompt).
# Captures the exit code of the previous command as its very first operation.
_bsh_precmd() {
  # CRITICAL: capture exit code FIRST — any operation before this overwrites $?
  local _bsh_exit=$?

  # Fast path: if plugin is disabled, do nothing (exit code already captured above).
  [[ $_BSH_ENABLED == 1 ]] || return 0

  # Store the exit code for use by Phase 2+ (audio, visual triggers)
  _BSH_LAST_EXIT=$_bsh_exit

  # Calculate command duration in seconds (SECONDS is always available; no subshell)
  # If _BSH_CMD_START_TIME is not set, use SECONDS so duration evaluates to 0.
  _BSH_CMD_DURATION=$(( SECONDS - ${_BSH_CMD_START_TIME:-$SECONDS} ))

  # Audio feedback (Phase 2)
  _bsh_audio_trigger

  # Reset start time for next command
  _BSH_CMD_START_TIME=$SECONDS
}

# Hook registration — dispatch based on detected shell (_BSH_SHELL set by compat.sh)
if [[ "${_BSH_SHELL:-}" == "zsh" ]]; then
  # zsh: use add-zsh-hook (autoloaded in compat.sh); appends to hook arrays without clobbering
  add-zsh-hook preexec _bsh_preexec
  add-zsh-hook precmd  _bsh_precmd
else
  # bash: use bash-preexec arrays (bash-preexec sourced in compat.sh)
  # += appends to the array — never overwrites existing hooks from other plugins
  preexec_functions+=(_bsh_preexec)
  precmd_functions+=(_bsh_precmd)
fi
