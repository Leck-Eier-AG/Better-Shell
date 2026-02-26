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
