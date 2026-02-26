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
      enabled)     _BSH_ENABLED="$value"     ;;
      ssh_enabled) _BSH_SSH_ENABLED="$value" ;;
      # Unknown keys are silently ignored (forward-compatible for Phase 2+ settings)
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

  # Reset start time for next command
  _BSH_CMD_START_TIME=$SECONDS

  # Phase 2+ will act on _BSH_LAST_EXIT and _BSH_CMD_DURATION here
  # (e.g., play audio feedback, trigger visual effects based on exit code and duration)
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
  printf '  theme:       %s\n' "${_BSH_THEME:-default}"
  printf '  version:     %s\n' "${_BSH_VERSION:-unknown}"
}

# bsh — Public dispatcher for user-facing plugin control.
# Usage: bsh on|off|status [--persist]
#   on       Set _BSH_ENABLED=1 (Better Shell active)
#   off      Set _BSH_ENABLED=0 (Better Shell inactive)
#   status   Print current state, shell, audio tool, theme, version
#   --persist  (with on/off) Write the new state to ${_BSH_DIR}/config so it
#              survives new shell sessions
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
    *)
      printf 'Usage: bsh on|off|status [--persist]\n' >&2
      return 1
      ;;
  esac
}
