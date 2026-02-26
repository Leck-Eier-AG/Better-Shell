# Phase 2: Audio - Research

**Researched:** 2026-02-26
**Domain:** Shell audio playback, cross-platform player detection, command filtering, sound pack structure
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Default vibe is **full meme sounds** — funny, dramatic, internet culture references
- Error examples: reverbed "Fahhh" for light fails, Plankton moaning "ahhhhh" for heavy fails
- Success sounds: ship both triumphant memes (MLG airhorn, "Let's go") AND chill satisfaction (Minecraft XP ding, Mario coin) — user chooses which style
- **3 bundled packs:** Meme (default), Chill, Retro (8-bit)
- Each pack has error, success, and warning sound variants
- Sounds scale in intensity/drama based on command weight
- User can choose scaling method: **duration-based** (longer command = more dramatic) or **command-type-based** (categorized commands)
- Both methods available, user picks which is active
- Each pack needs multiple intensity tiers (at minimum: light, medium, heavy)
- **Time threshold: 500ms default** — commands under 500ms are silent (configurable)
- **Three sound categories:** error (non-zero exit), success (zero exit), warning (zero exit + stderr output)
- Warning is a **distinct sound** — its own meme category, not a softer error
- **Sounds overlap** when commands fire rapidly — no cancellation, maximum chaos
- All audio playback is non-blocking (async, fire and forget)
- **Blacklist defaults:** interactive editors (vim, nvim, nano, emacs, vi), pagers/watchers (man, less, more, watch, top, htop), REPLs/sessions (python, node, irb, psql, mysql, ssh)
- Shell builtins (cd, source, export) NOT blacklisted — threshold handles them
- **Regex matching** for blacklist patterns — "python" catches python3, python3.12 etc.
- **Whitelist supported** — overrides both threshold and blacklist (e.g., "always sound for git push")
- **Changes take effect immediately** in current shell — no re-source needed (hot reload)
- **Two approaches:** folder drop-in (simple) + config mapping (precise)
- Drop-in: put files in ~/.config/better-shell/sounds/{error,success,warning}/
- Config: specify exact file paths in config for per-event override
- Config overrides folder drop-in when both exist
- **Any audio format** the system player supports — no format filtering
- **User-created packs:** a pack is a folder with error/, success/, warning/ subdirs. Drop in packs directory, switch by name. Shareable with others.
- **Configurable volume** (0-100) applied at playback time
- Auto-detect available player: afplay (macOS), aplay (ALSA/Linux), paplay (PulseAudio/PipeWire)
- Silent no-op on systems with no audio capability
- Volume control passed to player's native volume flag

### Claude's Discretion

- Exact meme sound selection and sourcing for bundled packs
- Intensity tier boundaries (what duration counts as "light" vs "heavy")
- Stderr detection implementation (capture method)
- Hot reload mechanism for blacklist/whitelist changes
- Internal pack folder structure and manifest format
- How volume maps to each player's native flags

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUD-01 | Play configurable sound on non-zero exit code (error) | _BSH_LAST_EXIT available from Phase 1 hooks; playback via player detection pattern |
| AUD-02 | Play configurable sound on success (zero exit code) | Same hook; branch on _BSH_LAST_EXIT == 0 with duration check |
| AUD-03 | Ship default bundled sound files (error beep, success chime) | CC0 sounds from freesound.org/pixabay; bundled in sounds/ directory under _BSH_DIR |
| AUD-04 | Allow user-provided custom sound files (.wav/.mp3) | Drop-in directory pattern; config path override; player accepts any format it supports |
| AUD-05 | Cross-platform audio playback (afplay/aplay/paplay detection) | Verified player flags: afplay -v, paplay --volume=0..65536, pw-play --volume=0..1; aplay has no volume flag — workaround documented |
| AUD-06 | All audio playback is non-blocking (async) | `cmd &` with disown + stdout/stderr redirected; job control message suppression via subshell with set +m |
| AUD-07 | Configurable time threshold (skip sounds for trivial commands) | _BSH_CMD_DURATION from Phase 1; compare against threshold variable before triggering |
| AUD-08 | Command blacklist (never trigger on vim, man, watch, etc.) | =~ ERE regex operator in bash/zsh; extract command name from _BSH_LAST_CMD; match against array of patterns |
| AUD-09 | Sound packs/themes with one-command swap (retro, minimal, dramatic) | Pack = directory structure; active pack stored as variable; bsh sound-pack <name> subcommand |
| AUD-10 | Detect and trigger on stderr output | Intercept via exec fd redirection in preexec; capture to tmpfile; check for content in precmd |
</phase_requirements>

---

## Summary

Phase 2 builds entirely on the hook variables established in Phase 1: `_BSH_LAST_EXIT`, `_BSH_CMD_DURATION`, and `_BSH_LAST_CMD` are all available when `_bsh_precmd` fires. The audio layer adds a new `lib/audio.sh` that reads these variables and dispatches non-blocking playback through whichever system audio player is available.

The three locked technical challenges are: (1) cross-platform player detection and volume normalization, (2) stderr detection for the warning trigger (AUD-10), and (3) hot-reloading of blacklist/whitelist config changes without re-sourcing. Each has a verified solution pattern described below.

Player detection is straightforward — probe with `command -v` at load time and store the result in `_BSH_AUDIO_TOOL`. Volume normalization is non-trivial because the three players use different scales (`afplay -v 0.0-1.0`, `paplay --volume=0-65536`, `pw-play --volume=0-1.0`, `aplay` has no volume flag at all). A mapping function must convert the user's 0-100 integer to each player's native scale. For aplay, volume must be handled via amixer pre-adjustment or by accepting that volume control is unsupported on ALSA-only systems. Stderr detection requires a file-descriptor trick in preexec to redirect stderr to a temp file, checked in precmd.

**Primary recommendation:** Implement `lib/audio.sh` as a pure shell module that hooks into `_bsh_precmd`, with `lib/audio-player.sh` handling player detection/dispatch and `sounds/` holding the bundled pack structure.

---

## Standard Stack

### Core

| Component | Version | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| afplay | macOS built-in | Play audio files on macOS | Ships with every macOS, supports -v volume flag, accepts MP3/WAV/AAC |
| aplay | ALSA utils 1.2.x | Play WAV on ALSA Linux | Universally available on ALSA systems; confirmed present on this machine (v1.2.15.2) |
| paplay | PulseAudio utils 17.x | Play audio on PulseAudio/PipeWire | Confirmed present (17.0); supports --volume=0..65536; PipeWire's PA compatibility layer makes it work on PipeWire systems too |
| pw-play | PipeWire native | Play audio on PipeWire | Also confirmed present; --volume=0..1.0; use as preferred player when available since it's native to modern Linux |

### Supporting

| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| amixer | ALSA utils | Set ALSA mixer volume before aplay | Only fallback for aplay volume control on ALSA-only systems |
| tmpfile (mktemp) | POSIX | Temporary file for stderr capture | Used in preexec/precmd stderr detection pattern |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| paplay for PipeWire | pw-play | pw-play is native PipeWire with simpler volume (0-1.0); paplay works via PulseAudio compat layer; both confirmed on this machine — prefer pw-play if available, paplay as fallback |
| aplay | mpv, sox play | mpv/sox not universally present, extra dependency; aplay is part of alsa-utils which is standard on all ALSA Linux systems |
| shell-only audio | Rust companion binary | User decisions locked to shell-only for Phase 2; Rust companion is a future option for Phase 4+ |

**Installation:** No installation needed — all players are system utilities. Sound files bundled in repo under `sounds/`.

---

## Architecture Patterns

### Recommended Project Structure

```
lib/
├── audio.sh          # _bsh_audio_trigger() — called from _bsh_precmd
├── audio-player.sh   # Player detection, dispatch, volume mapping
sounds/
├── meme/             # Default pack
│   ├── error/
│   │   ├── light.wav
│   │   ├── medium.wav
│   │   └── heavy.wav
│   ├── success/
│   │   ├── light.wav
│   │   ├── medium.wav
│   │   └── heavy.wav
│   └── warning/
│       ├── light.wav
│       ├── medium.wav
│       └── heavy.wav
├── chill/            # Same structure
└── retro/            # Same structure
tests/
└── test_audio.sh     # TAP-style, consistent with existing test_hooks.sh / test_toggle.sh
```

### Pattern 1: Non-Blocking Playback

**What:** Fire audio in background, suppress job control messages, and disconnect from the current shell so it cannot delay the next prompt.

**When to use:** Every audio trigger — always non-blocking.

```sh
# Source: verified bash behavior + linuxvox.com background job pattern
_bsh_play_sound() {
  local file="$1"
  local player="${_BSH_AUDIO_TOOL:-}"
  local vol="${_BSH_VOLUME:-70}"

  [[ -z "$player" || -z "$file" || ! -f "$file" ]] && return 0

  # Subshell with job control disabled prevents "[1]+ Done" messages
  ( set +m
    case "$player" in
      afplay)  afplay -v "$(_bsh_vol_afplay "$vol")" "$file" >/dev/null 2>&1 ;;
      pw-play) pw-play --volume="$(_bsh_vol_pw "$vol")" "$file" >/dev/null 2>&1 ;;
      paplay)  paplay --volume="$(_bsh_vol_paplay "$vol")" "$file" >/dev/null 2>&1 ;;
      aplay)   aplay -q "$file" >/dev/null 2>&1 ;;
    esac
  ) &
  disown $! 2>/dev/null
}
```

### Pattern 2: Player Detection at Load Time

**What:** Probe for players once at plugin load time and store in `_BSH_AUDIO_TOOL`. Never probe at playback time.

**When to use:** Once, during plugin initialization in audio-player.sh.

```sh
_bsh_detect_audio_player() {
  # Preference order: pw-play > paplay > afplay > aplay
  # pw-play is native PipeWire; paplay works via PA compat; afplay is macOS; aplay is ALSA fallback
  local p
  for p in pw-play paplay afplay aplay; do
    if command -v "$p" >/dev/null 2>&1; then
      _BSH_AUDIO_TOOL="$p"
      return 0
    fi
  done
  _BSH_AUDIO_TOOL=""  # No audio available — all playback is silent no-op
}
```

### Pattern 3: Volume Normalization

**What:** Map user's 0-100 integer to each player's native scale.

Verified player scales (confirmed via man pages and local --help on this machine):
- `afplay -v`: float 0.0-1.0 (docs say up to 255 but 0.0-1.0 is normal range)
- `pw-play --volume`: float 0.0-1.0 (confirmed: "--volume  Stream volume 0-1.0")
- `paplay --volume`: integer 0-65536 (confirmed: "--volume=VOLUME  Specify the initial (linear) volume in range 0...65536")
- `aplay`: NO volume flag — volume control not supported directly

```sh
_bsh_vol_afplay()  { awk "BEGIN { printf \"%.2f\", $1/100 }"; }
_bsh_vol_pw()      { awk "BEGIN { printf \"%.2f\", $1/100 }"; }
_bsh_vol_paplay()  { echo $(( $1 * 65536 / 100 )); }
# aplay: no volume flag — volume is at system mixer level only
```

### Pattern 4: Trigger Decision in precmd

**What:** Evaluate all conditions (enabled, threshold, blacklist, whitelist) before dispatching.

```sh
# Called from _bsh_precmd after _BSH_LAST_EXIT and _BSH_CMD_DURATION are set
_bsh_audio_trigger() {
  local exit_code="${_BSH_LAST_EXIT:-0}"
  local duration="${_BSH_CMD_DURATION:-0}"
  local cmd="${_BSH_LAST_CMD:-}"
  local cmd_name="${cmd%% *}"  # Extract first word (command name)

  # 1. Check whitelist first — overrides threshold and blacklist
  if _bsh_in_whitelist "$cmd_name"; then
    : # fall through to sound selection
  else
    # 2. Duration threshold check
    [[ "$duration" -lt "${_BSH_AUDIO_THRESHOLD:-1}" ]] && return 0

    # 3. Blacklist check
    _bsh_is_blacklisted "$cmd_name" && return 0
  fi

  # 4. Determine event type and intensity
  local event
  if [[ "$exit_code" -ne 0 ]]; then
    event="error"
  elif [[ -n "${_BSH_LAST_STDERR:-}" ]]; then
    event="warning"
  else
    event="success"
  fi

  local intensity
  intensity=$(_bsh_get_intensity "$duration")

  # 5. Resolve sound file
  local sound_file
  sound_file=$(_bsh_resolve_sound "$event" "$intensity")

  # 6. Play
  _bsh_play_sound "$sound_file"
}
```

### Pattern 5: Blacklist/Whitelist with ERE Regex

**What:** Store patterns as a delimited string (or array); test command name against each pattern using `=~`.

Both bash and zsh support `[[ string =~ pattern ]]` with POSIX ERE. In bash, avoid quoting the pattern variable on the right side of `=~` (quoting disables regex interpretation).

```sh
# _BSH_BLACKLIST is a colon-delimited string of ERE patterns
# Default: "^(vim|nvim|nano|emacs|vi|man|less|more|watch|top|htop|python|node|irb|psql|mysql|ssh)$"
_bsh_is_blacklisted() {
  local cmd_name="$1"
  local pattern
  # Split on colon; test each pattern
  while IFS=':' read -ra patterns; do
    for pattern in "${patterns[@]}"; do
      [[ -n "$pattern" ]] && [[ "$cmd_name" =~ $pattern ]] && return 0
    done
  done <<< "${_BSH_BLACKLIST:-}"
  return 1
}
```

Important: store default blacklist patterns such as `^python` (prefix match) not `^python$` so "python3" and "python3.12" match.

### Pattern 6: Stderr Detection

**What:** Detect whether the user's command wrote anything to stderr, to trigger the "warning" sound category.

**The challenge:** In an interactive shell, the hook system (preexec/precmd) runs inside the shell process — it cannot intercept the output of the user's command to a different file descriptor after the fact. The only reliable technique is to redirect stderr to a temporary file BEFORE the command runs (in preexec), check the file for content in precmd, then clean up.

**How it works:**
1. In `_bsh_preexec`: save the current stderr fd, open a tmpfile, redirect `exec 2>tmpfile`
2. The user's command runs with stderr going to tmpfile AND shown to terminal (requires tee via process substitution)
3. In `_bsh_precmd`: check tmpfile for content; set `_BSH_LAST_STDERR` accordingly; restore stderr; remove tmpfile

**Practical problem:** Transparent stderr interception (where stderr still shows to the user AND is captured) requires `exec 2> >(tee /tmp/bsh_stderr.$$)` — a process substitution that creates a background tee process. This works in bash and zsh but adds latency and complexity.

**Simpler alternative that the codebase should start with:** Check stderr by re-running... no, that's wrong. The practical recommended approach is:

Use the `exec 2>` redirect pattern with a temp FIFO that tees to both the original stderr and a capture file. However, this is fragile across shells and terminal emulators.

**Recommended implementation (Claude's Discretion area):** Use a tmpfile approach:

```sh
_bsh_preexec() {
  # ... existing code ...
  _BSH_STDERR_FILE="${TMPDIR:-/tmp}/bsh_stderr.$$"
  _BSH_STDERR_ORIG=  # signal that we opened it
  exec {_BSH_STDERR_FD}>&2            # save original stderr to new fd
  exec 2> >(tee -a "$_BSH_STDERR_FILE" >&${_BSH_STDERR_FD})  # tee stderr
}

_bsh_precmd() {
  local _bsh_exit=$?
  # ... existing code ...
  if [[ -f "${_BSH_STDERR_FILE:-}" ]]; then
    _BSH_LAST_STDERR=$(cat "$_BSH_STDERR_FILE" 2>/dev/null)
    rm -f "$_BSH_STDERR_FILE"
    # Restore stderr fd
    [[ -n "${_BSH_STDERR_FD:-}" ]] && exec 2>&${_BSH_STDERR_FD} && eval "exec ${_BSH_STDERR_FD}>&-"
  fi
}
```

**Caveat:** The `exec {varname}>&fd` syntax (dynamic fd allocation) requires bash 4.1+ and zsh. For bash 3.x compatibility, use a fixed fd number (e.g., fd 9). This project targets bash/zsh broadly; the POSIX-safe approach is a fixed high-numbered fd.

**Simpler fallback if tee approach proves too fragile:** Skip AUD-10 full implementation and set `_BSH_LAST_STDERR=""` always, meaning warning sounds never trigger. Document as known limitation. This avoids the complexity entirely. However, the CONTEXT.md lists warning as a distinct category, so the tee approach should be attempted.

### Pattern 7: Hot Reload of Config Variables

**What:** Blacklist, whitelist, volume, threshold, and active pack changes take effect immediately without re-sourcing the plugin.

**Implementation:** Read config on each `_bsh_precmd` call by checking file mtime against a stored value. Only re-parse when the file has changed. Cost: one `stat` call per prompt.

```sh
_bsh_audio_config_check() {
  local config="${_BSH_DIR}/config"
  [[ -f "$config" ]] || return 0
  local current_mtime
  current_mtime=$(stat -c %Y "$config" 2>/dev/null || stat -f %m "$config" 2>/dev/null)
  [[ "$current_mtime" == "${_BSH_CONFIG_MTIME:-}" ]] && return 0
  _BSH_CONFIG_MTIME="$current_mtime"
  _bsh_config_load  # re-read all keys including new audio keys
}
```

Note: `stat -c %Y` is Linux (GNU stat); `stat -f %m` is macOS (BSD stat). Both must be tried for cross-platform support.

### Pattern 8: Sound File Resolution

**What:** Given event type and intensity, return the path to the sound file to play.

Priority order (config override > drop-in folder > bundled pack):

```sh
_bsh_resolve_sound() {
  local event="$1"   # error|success|warning
  local intensity="$2"  # light|medium|heavy

  # 1. Config explicit override (Phase 4 will expand this)
  # For now, check if user has placed a file matching the event in drop-in dir
  local user_dir="${_BSH_SOUNDS_USER_DIR:-${HOME}/.config/better-shell/sounds}"
  local user_file="${user_dir}/${event}/${intensity}.wav"
  [[ -f "$user_file" ]] && { echo "$user_file"; return 0; }

  # Also check mp3
  user_file="${user_dir}/${event}/${intensity}.mp3"
  [[ -f "$user_file" ]] && { echo "$user_file"; return 0; }

  # 2. Bundled pack
  local pack="${_BSH_SOUND_PACK:-meme}"
  local bundled="${_BSH_DIR}/sounds/${pack}/${event}/${intensity}.wav"
  [[ -f "$bundled" ]] && { echo "$bundled"; return 0; }

  echo ""  # No file found — silent no-op
}
```

### Pattern 9: Intensity Calculation

**What:** Map command duration (seconds) or command type to a tier name.

Duration-based (default — Claude's Discretion for exact boundaries):

```sh
_bsh_get_intensity() {
  local duration="$1"
  # Boundaries: <5s = light, 5-30s = medium, >30s = heavy
  # These are Claude's discretion — reasonable defaults
  if   [[ "$duration" -lt 5 ]];  then echo "light"
  elif [[ "$duration" -lt 30 ]]; then echo "medium"
  else echo "heavy"
  fi
}
```

### Anti-Patterns to Avoid

- **Probing for audio players on every playback call:** Expensive. Detect once at load time, store in variable.
- **Using `wait` after background audio:** Defeats non-blocking requirement.
- **Calling `exec 2>...` without saving/restoring the original fd:** Will destroy the shell's stderr permanently, breaking output for subsequent commands.
- **Using `[[ "$cmd" =~ "$pattern" ]]` with the pattern quoted:** In bash, quoting the right-hand side of `=~` disables regex interpretation and forces literal string matching.
- **Reading sound files from absolute paths in user config:** Phase 4 concern. Phase 2 uses `_BSH_DIR`-relative paths only.
- **Firing audio on every precmd regardless of _BSH_ENABLED:** Check enabled state first (already set by Phase 1 toggle).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Audio format conversion | Format converter | Let system player handle it | afplay/paplay/aplay natively handle WAV, MP3, OGG depending on system codecs |
| Volume fade/crossfade | Custom mixer | Not needed | User decision: sounds overlap (maximum chaos), no cancellation |
| Job queue for audio | Async queue | `& disown` | Shell already provides background process support; queue adds complexity with no benefit |
| ERE regex engine | Custom pattern matcher | `[[ =~ ]]` builtin | Both bash and zsh have native ERE support; no external tool needed |
| File change detection | inotifywait daemon | mtime stat check in precmd | inotifywait requires inotify-tools installed, adds a background daemon; mtime check costs 1 stat() call/prompt which is negligible |

**Key insight:** Audio playback in shell is fundamentally delegated to system tools. The shell layer is pure dispatch logic — detect, decide, fire. Keep it thin.

---

## Common Pitfalls

### Pitfall 1: aplay Has No Volume Flag

**What goes wrong:** Code tries to pass a volume parameter to aplay and gets "unrecognized option".
**Why it happens:** aplay (ALSA) does not expose a per-invocation volume flag. Volume is controlled through the ALSA mixer state (`amixer`), which is global and persistent.
**How to avoid:** For aplay, either (a) accept no volume control and document it, or (b) call `amixer sset Master "$vol%"` before `aplay` — but this modifies global system volume which is unacceptable. **Recommended: skip volume for aplay.** The `_bsh_play_sound` function simply omits the volume flag for aplay.
**Warning signs:** `aplay: unrecognized option '--volume'` in test output.

### Pitfall 2: Job Control Messages Breaking Shell Output

**What goes wrong:** `[1]+ Done  afplay ...` appears in the terminal after background audio finishes.
**Why it happens:** Bash's job control monitor mode prints completion messages for background jobs.
**How to avoid:** Wrap background playback in a subshell with `set +m` to disable job control for that subshell only. This is a well-known pattern.
```sh
( set +m; afplay ... >/dev/null 2>&1 & )
```
**Warning signs:** `[1]+ Done` messages appearing at random times in the terminal.

### Pitfall 3: Stderr Interception Breaking Shell Output

**What goes wrong:** After implementing stderr capture, the user's command errors no longer appear on screen, or the shell's stderr fd is permanently redirected.
**Why it happens:** Incorrectly redirecting fd 2 in preexec without tee, or failing to restore it in precmd.
**How to avoid:** Always use `tee` to continue forwarding to original stderr. Always restore in precmd even if precmd is called via an exception path. Consider a trap for cleanup.
**Warning signs:** Error messages from commands becoming invisible to user.

### Pitfall 4: Regex Quoting in bash =~

**What goes wrong:** Pattern `^python` quoted as `"$pattern"` in `[[ "$cmd" =~ "$pattern" ]]` matches literally, not as ERE.
**Why it happens:** In bash, quoting the right-hand side of `=~` forces literal string matching. Zsh behaves differently (regex still applies).
**How to avoid:** Never quote the regex variable: `[[ "$cmd" =~ $pattern ]]`. Store patterns in variables, not string literals on the right side.
**Warning signs:** `vim` passes blacklist check when `_BSH_BLACKLIST="^vim"` is set.

### Pitfall 5: Sound Files Not Bundled in the Distributed better-shell.sh

**What goes wrong:** Users who clone the repo get no sound files, AUD-03 (bundled defaults) fails.
**Why it happens:** The build system (Makefile) concatenates shell files into better-shell.sh but cannot embed binary audio files.
**How to avoid:** Sound files must ship alongside the shell script — either in the repo as a `sounds/` directory that is part of the clone, or via a separate install step. The plugin's `_BSH_DIR` points to where both the script and sounds directory live. Document that `_BSH_DIR` must contain both.
**Warning signs:** `_bsh_resolve_sound` always returns empty string.

### Pitfall 6: Licensing Gap for Bundled Sounds

**What goes wrong:** Bundled meme sounds are copyright-encumbered (SpongeBob, MLG airhorn clips are from copyrighted works). Shipping them in the repo creates legal risk.
**Why it happens:** The user-desired sounds (Plankton, MLG airhorn) are derived from commercial media.
**How to avoid:** Two options: (a) Create original sounds that are inspired by memes but are themselves CC0 originals (recording a person saying "ahhh" is fine; using the actual SpongeBob clip is not). (b) Use Freesound.org / Pixabay CC0 sounds that evoke the same emotional register. Sources: freesound.org (CC0 filter), pixabay.com/sound-effects/search/cc0/, opengameart.org.
**This is the licensing gap flagged in STATE.md and remains unresolved for AUD-03.**
**Warning signs:** Repo contains .wav files with unclear licensing.

### Pitfall 7: `_BSH_LAST_CMD` Contains Entire Command Line, Not Just Command Name

**What goes wrong:** Blacklist check against `vim` fails for `vim -R myfile.txt` because the full string is `"vim -R myfile.txt"`, not `"vim"`.
**Why it happens:** `_BSH_LAST_CMD` stores the full command string as typed.
**How to avoid:** Extract command name with `${cmd%% *}` (remove everything after first space) before blacklist comparison. Handle edge cases: leading whitespace, aliases, function calls.
**Warning signs:** `vim myfile.txt` plays audio when it shouldn't.

---

## Code Examples

Verified patterns from official sources and live system testing:

### Player Detection (verified on this machine)

```sh
# Source: command -v is POSIX; verified aplay, paplay, pw-play present on this machine
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
```

### Volume Conversion (verified from man pages)

```sh
# afplay: -v 0.0-1.0 (confirmed: afplay man page via ss64.com)
_bsh_vol_afplay()  { awk "BEGIN { printf \"%.2f\", $1/100 }"; }

# pw-play: --volume 0.0-1.0 (confirmed: pw-play --help on this machine)
_bsh_vol_pw()      { awk "BEGIN { printf \"%.2f\", $1/100 }"; }

# paplay: --volume=0..65536 (confirmed: paplay --help on this machine, Debian man page)
_bsh_vol_paplay()  { echo $(( $1 * 65536 / 100 )); }

# aplay: no volume flag — omit entirely
```

### Non-Blocking Playback (verified bash behavior)

```sh
# Source: linuxvox.com background job suppression pattern; bash man page for set +m
_bsh_play_sound() {
  local file="$1"
  [[ -z "${_BSH_AUDIO_TOOL:-}" || -z "$file" || ! -f "$file" ]] && return 0
  (
    set +m  # disable job control monitor; suppresses "[1]+ Done" messages
    case "${_BSH_AUDIO_TOOL}" in
      pw-play) pw-play --volume="$(_bsh_vol_pw "${_BSH_VOLUME:-70}")" "$file" >/dev/null 2>&1 ;;
      paplay)  paplay --volume="$(_bsh_vol_paplay "${_BSH_VOLUME:-70}")" "$file" >/dev/null 2>&1 ;;
      afplay)  afplay -v "$(_bsh_vol_afplay "${_BSH_VOLUME:-70}")" "$file" >/dev/null 2>&1 ;;
      aplay)   aplay -q "$file" >/dev/null 2>&1 ;;
    esac
  ) &
  disown $! 2>/dev/null
}
```

### ERE Blacklist Match (verified bash =~ behavior)

```sh
# Source: bash man page; bash-hackers wiki on =~ operator
# IMPORTANT: do NOT quote the pattern variable on the right side of =~
_BSH_BLACKLIST_PATTERNS=("^vim$" "^nvim$" "^nano$" "^emacs$" "^vi$" "^man$" "^less$" "^more$" "^watch$" "^top$" "^htop$" "^python" "^node$" "^irb$" "^psql$" "^mysql$" "^ssh$")

_bsh_is_blacklisted() {
  local cmd_name="$1"
  local pattern
  for pattern in "${_BSH_BLACKLIST_PATTERNS[@]}"; do
    [[ "$cmd_name" =~ $pattern ]] && return 0
  done
  return 1
}
```

### Stat Mtime (cross-platform)

```sh
# Source: GNU stat man page (Linux); BSD stat man page (macOS)
_bsh_file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo "0"
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| PulseAudio as dominant Linux audio | PipeWire replacing PulseAudio | ~2021-2024 | pw-play should be preferred over paplay on modern Linux; paplay still works via compat layer |
| aplay as primary Linux player | aplay as last-resort fallback | Gradual | Modern Linux distros have PipeWire; aplay is for ALSA-only environments |
| Fixed fd numbers for redirection | Dynamic fd allocation (`exec {fd}>&2`) | bash 4.1+ | More robust but not bash 3.x compatible; use fixed fd (e.g., fd 9) for broader compat |

**Deprecated/outdated:**
- `ossplay`/`ogg123` for Linux: superseded by paplay/pw-play for general use; don't add to detection chain
- `mplayer` for audio: heavy dependency, not standard; avoid

---

## Open Questions

1. **Licensing for bundled meme sounds (AUD-03)**
   - What we know: CC0 sources exist (freesound.org, pixabay, opengameart.org) but none are the specific meme sounds requested (Plankton, MLG airhorn)
   - What's unclear: Whether original recordings that "sound like" memes are acceptable, or whether sourcing needs to be documented explicitly
   - Recommendation: For planning, scope AUD-03 as "source CC0 sounds from freesound.org that fit each emotional register (dramatic fail, triumphant win, warning)" rather than specific meme clips. Create a `sounds/SOURCES.txt` manifest tracking each file's license and origin. Exact sound selection is Claude's Discretion.

2. **Stderr detection reliability (AUD-10)**
   - What we know: The `exec 2> >(tee ...)` pattern works in bash and zsh but creates a background tee process per command, adds a small delay, and may break in unusual terminal configurations
   - What's unclear: Whether the complexity is worth it for a "nice to have" feature that most users won't notice
   - Recommendation: Implement as a separate plan item with a feature flag (`_BSH_STDERR_DETECT=0` by default). This lets the plan be split: implement error/success sounds first, add stderr/warning in a second plan once the core is stable.

3. **awk dependency for volume math**
   - What we know: `awk` is POSIX and universally available; used for float math that shell arithmetic cannot do
   - What's unclear: Whether awk subshell call on every playback adds noticeable latency (it won't — playback is async, so the awk call doesn't block the prompt)
   - Recommendation: Use awk. Alternatively, pre-compute volume values at load time and cache them in variables, avoiding awk on every play call.

4. **Bash array syntax vs. colon-delimited string for blacklist**
   - What we know: bash arrays (`_BSH_BLACKLIST_PATTERNS=("..." "...")`) are not POSIX but are available in bash 3.x+ and zsh
   - What's unclear: Whether Phase 4 config will need to set these dynamically from a config file (arrays are harder to serialize/deserialize from key=value config)
   - Recommendation: Use arrays internally but provide a string-based config key (colon-delimited) that gets parsed into the array at load time. This keeps the Phase 2 implementation clean while leaving a clear upgrade path for Phase 4.

---

## Sources

### Primary (HIGH confidence)

- Live system testing (`pw-play --help`, `paplay --help`, `aplay --help` on this machine) — confirmed all three players present, exact volume flags verified
- paplay man page (manpages.debian.org) — `--volume=0..65536` confirmed
- bash man page / bash-hackers wiki — `=~` operator behavior, `set +m`, `disown` behavior
- zsh documentation — `add-zsh-hook`, `=~` ERE behavior confirmed

### Secondary (MEDIUM confidence)

- ss64.com afplay man page — `-v 0.0-1.0` volume flag (macOS; not testable on this Linux system)
- madebynathan.com auto-reload bashrc — mtime checking pattern verified against bash behavior
- romkatv gist (zsh stderr capture) — demonstrates exec fd technique; confirmed approach is valid

### Tertiary (LOW confidence)

- Sound licensing landscape — CC0 sources identified (freesound.org, pixabay, opengameart.org); specific meme sounds not verified for CC0 availability
- `exec {varname}>&2` dynamic fd allocation — documented in bash 4.1+ manual; not tested against project's minimum bash version

---

## Metadata

**Confidence breakdown:**
- Standard stack (player detection, volume flags): HIGH — verified live on this machine and cross-referenced with man pages
- Architecture patterns (async playback, blacklist, hot reload): HIGH — well-established shell patterns with multiple verified sources
- Stderr detection (AUD-10): MEDIUM — approach is documented and plausible but complex; recommend implementation with feature flag
- Sound licensing (AUD-03): LOW — sources identified, specific meme sounds unresolved; blocks bundled sound selection

**Research date:** 2026-02-26
**Valid until:** 2026-09-01 (stable domain; audio player flags do not change frequently)
