# bash-preexec loader — bash only; wrapped so return cannot exit the sourced file
_bsh_load_bash_preexec() {
# bash-preexec v0.6.0 — https://raw.githubusercontent.com/rcaloras/bash-preexec/0.6.0/bash-preexec.sh
# bash-preexec.sh -- Bash support for ZSH-like 'preexec' and 'precmd' functions.
# https://github.com/rcaloras/bash-preexec
#
#
# 'preexec' functions are executed before each interactive command is
# executed, with the interactive command as its argument. The 'precmd'
# function is executed before each prompt is displayed.
#
# Author: Ryan Caloras (ryan@bashhub.com)
# Forked from Original Author: Glyph Lefkowitz
#
# V0.6.0
#

# General Usage:
#
#  1. Source this file at the end of your bash profile so as not to interfere
#     with anything else that's using PROMPT_COMMAND.
#
#  2. Add any precmd or preexec functions by appending them to their arrays:
#       e.g.
#       precmd_functions+=(my_precmd_function)
#       precmd_functions+=(some_other_precmd_function)
#
#       preexec_functions+=(my_preexec_function)
#
#  3. Consider changing anything using the DEBUG trap or PROMPT_COMMAND
#     to use preexec and precmd instead. Preexisting usages will be
#     preserved, but doing so manually may be less surprising.
#
#  Note: This module requires two Bash features which you must not otherwise be
#  using: the "DEBUG" trap, and the "PROMPT_COMMAND" variable. If you override
#  either of these after bash-preexec has been installed it will most likely break.

# Tell shellcheck what kind of file this is.
# shellcheck shell=bash

# Make sure this is bash that's running and return otherwise.
# Use POSIX syntax for this line:
if [ -z "${BASH_VERSION-}" ]; then
    return 1
fi

# We only support Bash 3.1+.
# Note: BASH_VERSINFO is first available in Bash-2.0.
if [[ -z "${BASH_VERSINFO-}" ]] || (( BASH_VERSINFO[0] < 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 1) )); then
    return 1
fi

# Avoid duplicate inclusion
if [[ -n "${bash_preexec_imported:-}" || -n "${__bp_imported:-}" ]]; then
    return 0
fi
bash_preexec_imported="defined"

# WARNING: This variable is no longer used and should not be relied upon.
# Use ${bash_preexec_imported} instead.
# shellcheck disable=SC2034
__bp_imported="${bash_preexec_imported}"

# Should be available to each precmd and preexec
# functions, should they want it. $? and $_ are available as $? and $_, but
# $PIPESTATUS is available only in a copy, $BP_PIPESTATUS.
# TODO: Figure out how to restore PIPESTATUS before each precmd or preexec
# function.
__bp_last_ret_value="$?"
BP_PIPESTATUS=("${PIPESTATUS[@]}")
__bp_last_argument_prev_command="$_"

__bp_inside_precmd=0
__bp_inside_preexec=0

# Initial PROMPT_COMMAND string that is removed from PROMPT_COMMAND post __bp_install
__bp_install_string=$'__bp_trap_string="$(trap -p DEBUG)"\ntrap - DEBUG\n__bp_install'

# Fails if any of the given variables are readonly
# Reference https://stackoverflow.com/a/4441178
__bp_require_not_readonly() {
    local var
    for var; do
        if ! ( unset "$var" 2> /dev/null ); then
            echo "bash-preexec requires write access to ${var}" >&2
            return 1
        fi
    done
}

# Remove ignorespace and or replace ignoreboth from HISTCONTROL
# so we can accurately invoke preexec with a command from our
# history even if it starts with a space.
__bp_adjust_histcontrol() {
    local histcontrol
    histcontrol="${HISTCONTROL:-}"
    histcontrol="${histcontrol//ignorespace}"
    # Replace ignoreboth with ignoredups
    if [[ "$histcontrol" == *"ignoreboth"* ]]; then
        histcontrol="ignoredups:${histcontrol//ignoreboth}"
    fi
    export HISTCONTROL="$histcontrol"
}

# This variable describes whether we are currently in "interactive mode";
# i.e. whether this shell has just executed a prompt and is waiting for user
# input.  It documents whether the current command invoked by the trace hook is
# run interactively by the user; it's set immediately after the prompt hook,
# and unset as soon as the trace hook is run.
__bp_preexec_interactive_mode=""

# These arrays are used to add functions to be run before, or after, prompts.
declare -a precmd_functions
declare -a preexec_functions

# Trims leading and trailing whitespace from $2 and writes it to the variable
# name passed as $1
__bp_trim_whitespace() {
    local var=${1:?} text=${2:-}
    text="${text#"${text%%[![:space:]]*}"}"   # remove leading whitespace characters
    text="${text%"${text##*[![:space:]]}"}"   # remove trailing whitespace characters
    printf -v "$var" '%s' "$text"
}


# Trims whitespace and removes any leading or trailing semicolons from $2 and
# writes the resulting string to the variable name passed as $1. Used for
# manipulating substrings in PROMPT_COMMAND
__bp_sanitize_string() {
    local var=${1:?} text=${2:-} sanitized
    __bp_trim_whitespace sanitized "$text"
    sanitized=${sanitized%;}
    sanitized=${sanitized#;}
    __bp_trim_whitespace sanitized "$sanitized"
    printf -v "$var" '%s' "$sanitized"
}

# This function is installed as part of the PROMPT_COMMAND;
# It sets a variable to indicate that the prompt was just displayed,
# to allow the DEBUG trap to know that the next command is likely interactive.
__bp_interactive_mode() {
    __bp_preexec_interactive_mode="on"
}


# This function is installed as part of the PROMPT_COMMAND.
# It will invoke any functions defined in the precmd_functions array.
__bp_precmd_invoke_cmd() {
    # Save the returned value from our last command, and from each process in
    # its pipeline. Note: this MUST be the first thing done in this function.
    # BP_PIPESTATUS may be unused, ignore
    # shellcheck disable=SC2034

    __bp_last_ret_value="$?" BP_PIPESTATUS=("${PIPESTATUS[@]}")

    # Don't invoke precmds if we are inside an execution of an "original
    # prompt command" by another precmd execution loop. This avoids infinite
    # recursion.
    if (( __bp_inside_precmd > 0 )); then
        return
    fi
    local __bp_inside_precmd=1

    # Invoke every function defined in our function array.
    local precmd_function
    for precmd_function in "${precmd_functions[@]}"; do

        # Only execute this function if it actually exists.
        # Test existence of functions with: declare -[Ff]
        if type -t "$precmd_function" 1>/dev/null; then
            __bp_set_ret_value "$__bp_last_ret_value" "$__bp_last_argument_prev_command"
            # Quote our function invocation to prevent issues with IFS
            "$precmd_function"
        fi
    done

    __bp_set_ret_value "$__bp_last_ret_value"
}

# Sets a return value in $?. We may want to get access to the $? variable in our
# precmd functions. This is available for instance in zsh. We can simulate it in bash
# by setting the value here.
__bp_set_ret_value() {
    return ${1:+"$1"}
}

__bp_in_prompt_command() {

    local prompt_command_array IFS=$'\n;'
    read -rd '' -a prompt_command_array <<< "${PROMPT_COMMAND[*]:-}"

    local trimmed_arg
    __bp_trim_whitespace trimmed_arg "${1:-}"

    local command trimmed_command
    for command in "${prompt_command_array[@]:-}"; do
        __bp_trim_whitespace trimmed_command "$command"
        if [[ "$trimmed_command" == "$trimmed_arg" ]]; then
            return 0
        fi
    done

    return 1
}

# This function is installed as the DEBUG trap.  It is invoked before each
# interactive prompt display.  Its purpose is to inspect the current
# environment to attempt to detect if the current command is being invoked
# interactively, and invoke 'preexec' if so.
__bp_preexec_invoke_exec() {

    # Save the contents of $_ so that it can be restored later on.
    # https://stackoverflow.com/questions/40944532/bash-preserve-in-a-debug-trap#40944702
    __bp_last_argument_prev_command="${1:-}"
    # Don't invoke preexecs if we are inside of another preexec.
    if (( __bp_inside_preexec > 0 )); then
        return
    fi
    local __bp_inside_preexec=1

    # Checks if the file descriptor is not standard out (i.e. '1')
    # __bp_delay_install checks if we're in test. Needed for bats to run.
    # Prevents preexec from being invoked for functions in PS1
    if [[ ! -t 1 && -z "${__bp_delay_install:-}" ]]; then
        return
    fi

    if [[ -n "${COMP_POINT:-}" || -n "${READLINE_POINT:-}" ]]; then
        # We're in the middle of a completer or a keybinding set up by "bind
        # -x".  This obviously can't be an interactively issued command.
        return
    fi
    if [[ -z "${__bp_preexec_interactive_mode:-}" ]]; then
        # We're doing something related to displaying the prompt.  Let the
        # prompt set the title instead of me.
        return
    else
        # If we're in a subshell, then the prompt won't be re-displayed to put
        # us back into interactive mode, so let's not set the variable back.
        # In other words, if you have a subshell like
        #   (sleep 1; sleep 2)
        # You want to see the 'sleep 2' as a set_command_title as well.
        if [[ 0 -eq "${BASH_SUBSHELL:-}" ]]; then
            __bp_preexec_interactive_mode=""
        fi
    fi

    if  __bp_in_prompt_command "${BASH_COMMAND:-}"; then
        # If we're executing something inside our prompt_command then we don't
        # want to call preexec. Bash prior to 3.1 can't detect this at all :/
        __bp_preexec_interactive_mode=""
        return
    fi

    local this_command
    this_command=$(LC_ALL=C HISTTIMEFORMAT='' builtin history 1)
    this_command="${this_command#*[[:digit:]][* ] }"

    # Sanity check to make sure we have something to invoke our function with.
    if [[ -z "$this_command" ]]; then
        return
    fi

    # Invoke every function defined in our function array.
    local preexec_function
    local preexec_function_ret_value
    local preexec_ret_value=0
    for preexec_function in "${preexec_functions[@]:-}"; do

        # Only execute each function if it actually exists.
        # Test existence of function with: declare -[fF]
        if type -t "$preexec_function" 1>/dev/null; then
            __bp_set_ret_value "${__bp_last_ret_value:-}"
            # Quote our function invocation to prevent issues with IFS
            "$preexec_function" "$this_command"
            preexec_function_ret_value="$?"
            if [[ "$preexec_function_ret_value" != 0 ]]; then
                preexec_ret_value="$preexec_function_ret_value"
            fi
        fi
    done

    # Restore the last argument of the last executed command, and set the return
    # value of the DEBUG trap to be the return code of the last preexec function
    # to return an error.
    # If `extdebug` is enabled a non-zero return value from any preexec function
    # will cause the user's command not to execute.
    # Run `shopt -s extdebug` to enable
    __bp_set_ret_value "$preexec_ret_value" "$__bp_last_argument_prev_command"
}

__bp_install() {
    # Exit if we already have this installed.
    if [[ "${PROMPT_COMMAND[*]:-}" == *"__bp_precmd_invoke_cmd"* ]]; then
        return 1
    fi

    trap '__bp_preexec_invoke_exec "$_"' DEBUG

    # Preserve any prior DEBUG trap as a preexec function
    eval "local trap_argv=(${__bp_trap_string:-})"
    local prior_trap=${trap_argv[2]:-}
    unset __bp_trap_string
    if [[ -n "$prior_trap" ]]; then
        eval '__bp_original_debug_trap() {
            '"$prior_trap"'
        }'
        preexec_functions+=(__bp_original_debug_trap)
    fi

    # Adjust our HISTCONTROL Variable if needed.
    __bp_adjust_histcontrol

    # Issue #25. Setting debug trap for subshells causes sessions to exit for
    # backgrounded subshell commands (e.g. (pwd)& ). Believe this is a bug in Bash.
    #
    # Disabling this by default. It can be enabled by setting this variable.
    if [[ -n "${__bp_enable_subshells:-}" ]]; then

        # Set so debug trap will work be invoked in subshells.
        set -o functrace > /dev/null 2>&1
        shopt -s extdebug > /dev/null 2>&1
    fi

    local existing_prompt_command
    # Remove setting our trap install string and sanitize the existing prompt command string
    existing_prompt_command="${PROMPT_COMMAND:-}"
    # Edge case of appending to PROMPT_COMMAND
    existing_prompt_command="${existing_prompt_command//$__bp_install_string/:}" # no-op
    existing_prompt_command="${existing_prompt_command//$'\n':$'\n'/$'\n'}" # remove known-token only
    existing_prompt_command="${existing_prompt_command//$'\n':;/$'\n'}" # remove known-token only
    __bp_sanitize_string existing_prompt_command "$existing_prompt_command"
    if [[ "${existing_prompt_command:-:}" == ":" ]]; then
        existing_prompt_command=
    fi

    # Install our hooks in PROMPT_COMMAND to allow our trap to know when we've
    # actually entered something.
    PROMPT_COMMAND='__bp_precmd_invoke_cmd'
    PROMPT_COMMAND+=${existing_prompt_command:+$'\n'$existing_prompt_command}
    if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
        PROMPT_COMMAND+=('__bp_interactive_mode')
    else
        # shellcheck disable=SC2179 # PROMPT_COMMAND is not an array in bash <= 5.0
        PROMPT_COMMAND+=$'\n__bp_interactive_mode'
    fi

    # Add two functions to our arrays for convenience
    # of definition.
    precmd_functions+=(precmd)
    preexec_functions+=(preexec)

    # Invoke our two functions manually that were added to $PROMPT_COMMAND
    __bp_precmd_invoke_cmd
    __bp_interactive_mode
}

# Sets an installation string as part of our PROMPT_COMMAND to install
# after our session has started. This allows bash-preexec to be included
# at any point in our bash profile.
__bp_install_after_session_init() {
    # bash-preexec needs to modify these variables in order to work correctly
    # if it can't, just stop the installation
    __bp_require_not_readonly PROMPT_COMMAND HISTCONTROL HISTTIMEFORMAT || return

    local sanitized_prompt_command
    __bp_sanitize_string sanitized_prompt_command "${PROMPT_COMMAND:-}"
    if [[ -n "$sanitized_prompt_command" ]]; then
        # shellcheck disable=SC2178 # PROMPT_COMMAND is not an array in bash <= 5.0
        PROMPT_COMMAND=${sanitized_prompt_command}$'\n'
    fi
    # shellcheck disable=SC2179 # PROMPT_COMMAND is not an array in bash <= 5.0
    PROMPT_COMMAND+=${__bp_install_string}
}

# Run our install so long as we're not delaying it.
if [[ -z "${__bp_delay_install:-}" ]]; then
    __bp_install_after_session_init
fi

}
[ -n "${BASH_VERSION-}" ] && _bsh_load_bash_preexec
unset -f _bsh_load_bash_preexec 2>/dev/null

# Better Shell — Header
# Idempotency guard, version, and directory setup.
# This file is sourced first in the concatenated better-shell.sh.

# Idempotency guard: no-op if already loaded
[[ -n "${_BSH_LOADED:-}" ]] && return 0
_BSH_LOADED=1

# Plugin directory — users can override by setting _BSH_DIR before sourcing
_BSH_DIR="${_BSH_DIR:-${HOME}/.better-shell}"

# Version
_BSH_VERSION="0.1.0"

# Enable/disable state (default: on)
_BSH_ENABLED=1

# SSH sessions: disabled by default; set _BSH_SSH_ENABLED=1 to enable
_BSH_SSH_ENABLED=0
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
      stderr_detect)   _BSH_STDERR_DETECT="$value"    ;;
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
# Better Shell — Environment Detection
# Defines _bsh_is_interactive() and gates all subsequent code on it.

# Returns 0 if the current shell environment is interactive and should load Better Shell.
# Returns 1 (and silently exits) for: non-interactive shells, no TTY, SSH (unless opted in),
# and known CI environments.
_bsh_is_interactive() {
  # Must be an interactive shell ($- contains 'i')
  [[ $- == *i* ]] || return 1

  # Must have a real TTY attached (not piped, not a subshell script)
  [[ -t 1 ]] || return 1

  # SSH check: SSH_TTY is set for interactive SSH sessions; SSH_CLIENT for all SSH.
  # Disabled by default — user must set _BSH_SSH_ENABLED=1 to load plugin in SSH.
  if [[ -n "${SSH_TTY:-}" || -n "${SSH_CLIENT:-}" ]]; then
    [[ "${_BSH_SSH_ENABLED:-0}" == "1" ]] || return 1
  fi

  # Known CI environments: never load plugin in CI
  if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${JENKINS_URL:-}" ]]; then
    return 1
  fi

  return 0
}

# Gate: if not interactive, return from this file immediately (and from the concatenated
# better-shell.sh). All subsequent lib files are only evaluated if this passes.
_bsh_is_interactive || return 0
# Better Shell — Shell Compatibility Layer
# Detects bash vs zsh, loads bash-preexec for bash, sets up add-zsh-hook for zsh.

# Shell detection — set _BSH_SHELL to "bash" or "zsh"
if [[ -n "${ZSH_VERSION:-}" ]]; then
  _BSH_SHELL="zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
  _BSH_SHELL="bash"
else
  # Unknown shell — silently bail, do not load plugin
  return 0
fi

if [[ "$_BSH_SHELL" == "zsh" ]]; then
  # zsh: load the hook utility (built-in to zsh 5.3+)
  # Hook registration happens in hooks.sh after functions are defined.
  # Note: zsh hook functions should use 'emulate -L zsh' to guard against unusual
  # zsh option states inherited from frameworks (prezto, zi, etc.)
  autoload -Uz add-zsh-hook

else
  # bash: source bash-preexec
  # In the built better-shell.sh, bash-preexec is already concatenated at the top.
  # During development (sourcing lib files individually), fall back to the vendor file.
  if ! declare -f __bp_preexec_invoke_exec >/dev/null 2>&1; then
    # Not already loaded — try the vendor path (development mode)
    if [[ -f "${_BSH_DIR}/vendor/bash-preexec.sh" ]]; then
      # shellcheck source=vendor/bash-preexec.sh
      source "${_BSH_DIR}/vendor/bash-preexec.sh"
    elif [[ -f "$(dirname "${BASH_SOURCE[0]:-}")"/../vendor/bash-preexec.sh ]]; then
      source "$(dirname "${BASH_SOURCE[0]:-}")"/../vendor/bash-preexec.sh
    else
      # bash-preexec not found — log warning and continue without preexec support
      printf 'Better Shell: warning: bash-preexec not found; preexec hook unavailable\n' >&2
      return 0
    fi
  fi

  # Verify bash-preexec loaded correctly
  if ! declare -p preexec_functions >/dev/null 2>&1 && ! declare -f __bp_preexec_invoke_exec >/dev/null 2>&1; then
    printf 'Better Shell: warning: bash-preexec failed to initialize\n' >&2
  fi
fi
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

  # Stderr detection (opt-in via _BSH_STDERR_DETECT=1).
  # Sets up a tee redirect so _bsh_precmd can detect whether the command produced
  # any stderr output and fire a warning event instead of success.
  # fd 9 is used to save the original stderr (fixed fd, bash 3.x compatible).
  if [[ "${_BSH_STDERR_DETECT:-0}" == "1" ]]; then
    _BSH_STDERR_FILE="${TMPDIR:-/tmp}/bsh_stderr.$$"
    : > "$_BSH_STDERR_FILE"   # truncate/create the capture file
    exec 9>&2                  # save original stderr to fd 9
    exec 2> >(tee -a "$_BSH_STDERR_FILE" >&9)  # tee to file AND original stderr
  fi
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

  # Stderr detection cleanup: check captured output and restore stderr.
  # Must happen BEFORE _bsh_audio_trigger so the warning decision sees _BSH_LAST_STDERR.
  _BSH_LAST_STDERR=""
  if [[ "${_BSH_STDERR_DETECT:-0}" == "1" && -f "${_BSH_STDERR_FILE:-}" ]]; then
    [[ -s "$_BSH_STDERR_FILE" ]] && _BSH_LAST_STDERR="1"  # non-empty file = has stderr
    rm -f "$_BSH_STDERR_FILE"
    exec 2>&9 9>&-  # restore original stderr, close saved fd
  fi

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
#   2. Determine event type FIRST: error | warning | success
#   3. Whitelist match → skip threshold & blacklist, play
#   4. Error event → skip threshold (fast errors must always play), check blacklist
#   5. Non-error event → apply whitelist/threshold/blacklist as before
#   6. Resolve intensity from duration
#   7. Resolve sound file → play
_bsh_audio_trigger() {
  # Hot reload: pick up config file changes without re-sourcing
  _bsh_audio_config_check

  # Guard: no audio player means total silence
  [[ -z "${_BSH_AUDIO_TOOL:-}" ]] && return 0

  # Extract just the command name (first word, no args)
  local cmd_name="${_BSH_LAST_CMD%% *}"

  # Determine event type FIRST so errors can bypass the duration threshold.
  # Error sounds must always play — the threshold was designed to suppress
  # trivial successes, not to silence fast-failing commands.
  local event
  if [[ "${_BSH_LAST_EXIT:-0}" -ne 0 ]]; then
    event="error"
  elif [[ -n "${_BSH_LAST_STDERR:-}" ]]; then
    event="warning"
  else
    event="success"
  fi

  # Whitelist overrides threshold and blacklist for all event types
  if ! _bsh_in_whitelist "$cmd_name"; then
    if [[ "$event" == "error" ]]; then
      # Error events bypass the threshold — fast-failing commands (duration=0)
      # must play an error sound. Blacklist still applies: no error sounds
      # from interactive editors/REPLs the user chose to run.
      _bsh_is_blacklisted "$cmd_name" && return 0
    else
      # Non-error (success/warning): apply threshold then blacklist
      [[ "${_BSH_CMD_DURATION:-0}" -lt "${_BSH_AUDIO_THRESHOLD:-1}" ]] && return 0
      _bsh_is_blacklisted "$cmd_name" && return 0
    fi
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
# Better Shell — Toggle Command
# Provides the public `bsh` function: bsh on|off|status [--persist]

# _bsh_print_status — Print current plugin state to stdout.
# Called by `bsh status`.
_bsh_print_status() {
  local state
  if [[ "${_BSH_ENABLED:-1}" == "1" ]]; then
    state="enabled"
  else
    state="disabled"
  fi

  printf 'Better Shell status\n'
  printf '  state:       %s\n' "$state"
  printf '  shell:       %s\n' "${_BSH_SHELL:-unknown}"
  printf '  audio tool:  %s\n' "${_BSH_AUDIO_TOOL:-not detected}"
  printf '  sound pack:  %s\n' "${_BSH_SOUND_PACK:-meme}"
  printf '  volume:      %s\n' "${_BSH_VOLUME:-70}"
  printf '  theme:       %s\n' "${_BSH_THEME:-default}"
  printf '  version:     %s\n' "${_BSH_VERSION:-unknown}"
}

# bsh — Public dispatcher for user-facing plugin control.
# Usage: bsh on|off|status|sound-pack|volume [args] [--persist]
#   on              Set _BSH_ENABLED=1 (Better Shell active)
#   off             Set _BSH_ENABLED=0 (Better Shell inactive)
#   status          Print current state, shell, audio tool, pack, volume, theme, version
#   sound-pack      Show active pack and list available packs
#   sound-pack <n>  Switch to named sound pack and persist the choice
#   volume          Show current volume (0-100)
#   volume <n>      Set volume (0-100) and persist
#   --persist       (with on/off) Write the new state to ${_BSH_DIR}/config
bsh() {
  local subcmd="${1:-}"
  local flag="${2:-}"
  case "$subcmd" in
    on)
      _BSH_ENABLED=1
      [[ "$flag" == "--persist" ]] && _bsh_config_set "enabled" "1"
      printf 'Better Shell: on\n'
      ;;
    off)
      _BSH_ENABLED=0
      [[ "$flag" == "--persist" ]] && _bsh_config_set "enabled" "0"
      printf 'Better Shell: off\n'
      ;;
    status)
      _bsh_print_status
      ;;
    sound-pack)
      if [[ -z "${2:-}" ]]; then
        printf 'Active pack: %s\n' "${_BSH_SOUND_PACK:-meme}"
        printf 'Available packs:\n'
        # List bundled packs
        local p
        for p in "${_BSH_DIR}"/sounds/*/; do
          [[ -d "$p" ]] && printf '  %s\n' "$(basename "$p")"
        done
        # List user custom packs
        local user_packs="${HOME}/.config/better-shell/packs"
        if [[ -d "$user_packs" ]]; then
          for p in "${user_packs}"/*/; do
            [[ -d "$p" ]] && printf '  %s (user)\n' "$(basename "$p")"
          done
        fi
      else
        _BSH_SOUND_PACK="$2"
        _bsh_config_set sound_pack "$2"
        printf 'Sound pack set to: %s\n' "$2"
      fi
      ;;
    volume)
      if [[ -z "${2:-}" ]]; then
        printf 'Volume: %s\n' "${_BSH_VOLUME:-70}"
      else
        _BSH_VOLUME="$2"
        _bsh_config_set volume "$2"
        printf 'Volume set to: %s\n' "$2"
      fi
      ;;
    *)
      printf 'Usage: bsh on|off|status|sound-pack [<name>]|volume [<0-100>] [--persist]\n' >&2
      return 1
      ;;
  esac
}
