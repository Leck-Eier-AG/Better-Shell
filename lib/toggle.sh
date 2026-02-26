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
