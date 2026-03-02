#!/usr/bin/env sh
# better-shell.sh — Play a random sound when a command errors.
# Source this file from your .bashrc or .zshrc.

# ---------- guard against double-sourcing ----------
[ "${__BETTER_SHELL_LOADED:-0}" = "1" ] && return 0
__BETTER_SHELL_LOADED=1

# ---------- config defaults ----------
BETTER_SHELL_ENABLED="${BETTER_SHELL_ENABLED:-1}"
BETTER_SHELL_VOLUME="${BETTER_SHELL_VOLUME:-100}"

# ---------- resolve script directory ----------
__better_shell_script_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] 2>/dev/null; then
    __better_shell_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
    __better_shell_script_dir="$(cd "$(dirname "${(%):-%x}")" && pwd)"
fi

# ---------- resolve sounds directory ----------
__better_shell_resolve_sounds_dir() {
    if [ -n "${BETTER_SHELL_SOUNDS_DIR:-}" ] && [ -d "$BETTER_SHELL_SOUNDS_DIR" ]; then
        echo "$BETTER_SHELL_SOUNDS_DIR"
    elif [ -d "$HOME/.better-shell/sounds" ]; then
        echo "$HOME/.better-shell/sounds"
    elif [ -n "$__better_shell_script_dir" ] && [ -d "$__better_shell_script_dir/sounds" ]; then
        echo "$__better_shell_script_dir/sounds"
    fi
}

# ---------- audio player detection ----------
__better_shell_player=""
__better_shell_detect_player() {
    for cmd in ffplay mpv play paplay aplay; do
        if command -v "$cmd" >/dev/null 2>&1; then
            __better_shell_player="$cmd"
            return 0
        fi
    done
    return 1
}
__better_shell_detect_player

# ---------- play a sound file ----------
__better_shell_play() {
    local file="$1"
    [ -z "$__better_shell_player" ] && return 1
    case "$__better_shell_player" in
        paplay)
            paplay "$file" &
            ;;
        aplay)
            aplay "$file" &
            ;;
        ffplay)
            ffplay -nodisp -autoexit -loglevel quiet -volume "$BETTER_SHELL_VOLUME" "$file" &
            ;;
        mpv)
            mpv --no-video --really-quiet --volume="$BETTER_SHELL_VOLUME" "$file" &
            ;;
        play)
            play -q -v "$(awk "BEGIN{printf \"%.2f\", $BETTER_SHELL_VOLUME/100}")" "$file" &
            ;;
    esac
    disown 2>/dev/null
}

# ---------- pick a random sound and play it ----------
__better_shell_error_sound() {
    [ "${BETTER_SHELL_ENABLED:-1}" != "1" ] && return 0

    local sounds_dir
    sounds_dir="$(__better_shell_resolve_sounds_dir)"
    [ -z "$sounds_dir" ] && return 1

    local files=()
    # NULL_GLOB: unmatched globs expand to nothing (zsh errors on them by default)
    [ -n "${ZSH_VERSION:-}" ] && setopt local_options NULL_GLOB
    for f in "$sounds_dir"/*.mp3 "$sounds_dir"/*.wav "$sounds_dir"/*.ogg; do
        [ -f "$f" ] && files+=("$f")
    done
    [ ${#files[@]} -eq 0 ] && return 1

    local idx=$(( RANDOM % ${#files[@]} ))
    __better_shell_play "${files[$idx]}"
}

# ---------- hook into prompt ----------
__better_shell_cmd_ran=0

if [ -n "${ZSH_VERSION:-}" ]; then
    # preexec fires only when a real command is executed (not empty enter)
    __better_shell_preexec() {
        __better_shell_cmd_ran=1
    }
    # Capture $? before other precmd hooks (e.g. oh-my-zsh) clobber it
    __better_shell_save_exit() {
        __better_shell_exit_code=$?
    }
    __better_shell_precmd() {
        if [ "$__better_shell_cmd_ran" = "1" ] && [ "$__better_shell_exit_code" -ne 0 ]; then
            __better_shell_error_sound
        fi
        __better_shell_cmd_ran=0
    }
    autoload -Uz add-zsh-hook
    # save_exit must be first in the precmd chain to capture the real exit code
    precmd_functions=(__better_shell_save_exit $precmd_functions)
    add-zsh-hook preexec __better_shell_preexec
    add-zsh-hook precmd __better_shell_precmd
elif [ -n "${BASH_VERSION:-}" ]; then
    __better_shell_last_histnum=""
    __better_shell_prompt_command() {
        local exit_code=$?
        # Compare history number to detect if a real command ran
        local cur_histnum
        cur_histnum="$(history 1 2>/dev/null | awk '{print $1}')"
        if [ "$cur_histnum" != "$__better_shell_last_histnum" ] && [ "$exit_code" -ne 0 ]; then
            __better_shell_error_sound
        fi
        __better_shell_last_histnum="$cur_histnum"
    }
    if [[ "$PROMPT_COMMAND" == *"__better_shell_prompt_command"* ]]; then
        : # already registered
    elif [ -n "$PROMPT_COMMAND" ]; then
        PROMPT_COMMAND="__better_shell_prompt_command;${PROMPT_COMMAND}"
    else
        PROMPT_COMMAND="__better_shell_prompt_command"
    fi
fi
