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
