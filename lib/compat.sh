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
