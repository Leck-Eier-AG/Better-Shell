# Pitfalls Research

**Domain:** Shell plugin with audio/visual effects (hooks, async audio, ANSI rendering, POSIX compatibility)
**Researched:** 2026-02-26
**Confidence:** MEDIUM-HIGH (core hook/trap behavior HIGH from official docs and bash-preexec source; audio environment issues MEDIUM from community sources; UX patterns MEDIUM from community discussions)

---

## Critical Pitfalls

### Pitfall 1: Blocking Operations in precmd/preexec Hooks

**What goes wrong:**
Any synchronous operation in `precmd` or `preexec` adds latency to every single prompt render or command dispatch. A hook that takes 11ms is unacceptable — users notice delays above ~5ms as sluggishness. Spawning an audio player synchronously (e.g., `aplay sound.wav` without `&`) blocks the shell entirely until playback completes.

**Why it happens:**
Developers test with fast machines and short sounds. They write hooks sequentially because it's simpler, and it "works fine" in local testing. The problem only surfaces under real use: slow filesystems, heavy system load, or longer sound files.

**How to avoid:**
All audio playback MUST run asynchronously. Always background the playback process:
```sh
aplay "$sound_file" &>/dev/null &
```
For visual effects (spinners), they must run in a background subshell or use async Zsh patterns (`zsh-async` library). Never call `wait` on audio processes inside a hook. Measure hook execution time during development with `EPOCHREALTIME` before and after.

**Warning signs:**
- Prompt appears noticeably delayed after running any command
- `time echo hello` shows unexpected overhead beyond a few milliseconds
- Shell feels "stuck" briefly after commands complete
- Amazon Q CLI issue #844 documents an 11ms hook causing user complaints as a reference threshold

**Phase to address:** Core hook infrastructure phase (earliest). Establish the async pattern before any audio or visual feature is wired in.

---

### Pitfall 2: DEBUG Trap Clobbering (Bash)

**What goes wrong:**
In Bash, there is no native `preexec` hook. The common workaround is a `DEBUG` trap. When your plugin sets `trap '...' DEBUG`, it overwrites any existing `DEBUG` trap set by other tools (iTerm2 shell integration, VSCode terminal, other prompt plugins, `bash-preexec` itself). The result: the other tool's hook silently stops working, or worse, yours stops working when the user has other plugins installed. This causes hard-to-diagnose breakage that only appears in certain user environments.

**Why it happens:**
Bash only supports one `DEBUG` trap handler at a time. Developers write the trap directly without checking what's already registered. They test in a clean environment without other shell tools present.

**How to avoid:**
Never set `trap '...' DEBUG` directly. Use [bash-preexec](https://github.com/rcaloras/bash-preexec) as the hook multiplexer — it provides `preexec_functions` and `precmd_functions` arrays that allow multiple handlers to coexist. Detect if bash-preexec is already loaded before sourcing it:
```sh
if [[ -z "${__bp_imported:-}" ]]; then
  source /path/to/bash-preexec.sh
fi
# Then append, never replace:
preexec_functions+=(_better_shell_preexec)
precmd_functions+=(_better_shell_precmd)
```
Also: bash-preexec **must be sourced last** in the rc file, after all other plugins.

**Warning signs:**
- Users report that their prompt theme, iTerm2 integration, or VSCode terminal integration stops working after installing your plugin
- Your hooks stop firing when user has other shell tools installed
- Issue reports clustered around specific other tools (iterm2, starship, oh-my-zsh)

**Phase to address:** Core hook infrastructure phase. This is an architectural decision — get it right before building any feature on top of hooks.

---

### Pitfall 3: Zsh Hook Overwrite Instead of Appending

**What goes wrong:**
In Zsh, the naive pattern `precmd() { ... }` defines a single hook function, silently replacing any existing `precmd` defined by other plugins (e.g., a prompt theme). This destroys the other plugin's functionality without any error or warning.

**Why it happens:**
Developers are unfamiliar with `add-zsh-hook`. Defining a function feels natural. The breakage only surfaces when the user has multiple plugins.

**How to avoid:**
Always use `add-zsh-hook` to register hooks. This appends to the hook array rather than replacing it:
```zsh
autoload -Uz add-zsh-hook
add-zsh-hook precmd  _better_shell_precmd
add-zsh-hook preexec _better_shell_preexec
```
Similarly, use `add-zle-hook-widget` for ZLE editor hooks rather than redefining widget functions.

**Warning signs:**
- User reports prompt theme stops showing git status or decorations after installing your plugin
- User reports their other shell plugin's behavior disappears
- Testing only with a clean `.zshrc` with no other plugins

**Phase to address:** Core hook infrastructure phase. Enforce as a code-level constraint from day one.

---

### Pitfall 4: Audio Playback Fails Silently in Common Environments

**What goes wrong:**
The plugin hardcodes one audio tool (e.g., `aplay`) or fails ungracefully when the expected tool is absent. `aplay` fails silently or with an error on systems using PipeWire without the ALSA compatibility layer. `paplay` fails if `PULSE_SERVER` or `XDG_CONFIG_HOME` environment variables are missing. Audio completely fails in WSL2 (no native audio device). Container environments (Docker, CI) have no audio at all. SSH sessions on headless servers also have no audio.

**Why it happens:**
Developers test on their primary machine which has audio configured. They don't test in WSL2, SSH sessions, or CI environments. They assume one tool covers all Linux systems.

**How to avoid:**
Implement a platform-detection and graceful degradation strategy at startup:
```sh
_better_shell_detect_audio() {
  if command -v afplay  &>/dev/null; then echo "afplay";
  elif command -v paplay  &>/dev/null; then echo "paplay";
  elif command -v aplay   &>/dev/null; then echo "aplay";
  elif command -v pw-play &>/dev/null; then echo "pw-play";
  else echo "none"; fi
}
```
If no audio tool is found, disable audio features silently — do not error. Provide a `BETTER_SHELL_NO_AUDIO=1` environment variable as an explicit opt-out. Test audio features in WSL2, SSH sessions, and a minimal Docker container.

**Warning signs:**
- Error messages like `aplay: main:788: audio open error: No such file or directory` appearing in user terminals
- Users on WSL2 or headless servers report error spam from the plugin
- Issue reports from macOS users (they need `afplay`, not `aplay`)

**Phase to address:** Audio integration phase. The detection/fallback mechanism must be the first thing built before any actual audio feature.

---

### Pitfall 5: Namespace Pollution (Variables and Functions)

**What goes wrong:**
Using short, generic variable names (e.g., `THEME`, `CONFIG`, `last_cmd`) or unprefixed functions (e.g., `play_sound()`, `show_spinner()`) collides with user-defined variables, other plugins, or shell builtins. The collision causes silent data corruption or broken behavior that is nearly impossible to debug. Using the `_` prefix for functions appears safe but actually collides with Zsh's completion function namespace (completion functions all start with `_`).

**Why it happens:**
Developers write the plugin for their own use first, with convenient short names. The problem only surfaces when the plugin is used alongside other tools.

**How to avoid:**
Prefix ALL functions and variables with a unique plugin identifier (e.g., `_bs_` or `__better_shell_`):
- Variables: `_BS_CONFIG_PATH`, `_BS_AUDIO_TOOL`, `_BS_LAST_EXIT`
- Private functions: `__bs_play_sound()`, `__bs_detect_audio()`
- Public API functions: `bs_add_trigger()`, `bs_mute()`
- Use `local` religiously inside all functions to prevent variable leakage
- Enable `setopt WARN_CREATE_GLOBAL` in Zsh during development to catch accidental globals

**Warning signs:**
- User reports that setting a variable in their shell breaks your plugin, or vice versa
- Completion system breaks after installing your plugin
- Works fine alone, breaks in combination with oh-my-zsh or prezto

**Phase to address:** Foundation phase (naming conventions must be established before writing any code). Enforce with a linter or code review checklist.

---

### Pitfall 6: Visual Output Breaking Non-Interactive and Piped Usage

**What goes wrong:**
ANSI escape codes, spinner animations, and ASCII art output written to stdout/stderr corrupt piped data and script output. A user running `better-shell-cmd | grep foo` gets the spinner frames in the grep input. Scripts that source the rc file in a non-interactive context get garbage escape codes in their output. CI/CD pipelines that source `.bashrc` for environment setup get visual noise that breaks log parsing.

**Why it happens:**
Developers only test interactively. Piped usage and non-interactive sourcing are afterthoughts.

**How to avoid:**
At the top of the plugin, detect whether the shell is interactive and whether output is a TTY:
```sh
[[ -o interactive ]] || return  # Zsh: exit early if non-interactive
[[ -t 1 ]] || return            # POSIX: exit early if stdout is not a TTY
```
All visual output must go to stderr (not stdout), and only when stderr is also a TTY. Honor the `NO_COLOR` environment variable ([no-color.org](https://no-color.org/)) to disable all ANSI output. Provide `BETTER_SHELL_NO_VISUAL=1` as an explicit opt-out.

**Warning signs:**
- User reports garbled output when using your plugin in scripts
- CI systems show ANSI escape sequences in logs after sourcing the rc file
- `echo "test" | cat` produces unexpected extra characters

**Phase to address:** Foundation phase. Non-interactive detection must be implemented before any visual feature is added.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hardcode `aplay` for Linux audio | Simple first implementation | Breaks on PipeWire-only, WSL2, macOS | Never — detection takes 10 lines |
| Define `precmd()` directly in Zsh | One less dependency | Silently breaks other plugins' hooks | Never — use `add-zsh-hook` always |
| Short variable names without prefix | Faster to type | Namespace collisions with any other plugin or user variable | Never |
| Synchronous audio playback in hooks | Simpler code | Perceptible latency on every command | Never |
| Write ANSI codes unconditionally | Simpler rendering code | Breaks piped usage, CI, non-interactive shells, `NO_COLOR` users | Never |
| Skip unload function | Saves development time | Plugin can never be cleanly disabled or hot-reloaded by plugin managers | Acceptable for MVP, must add before v1.0 |
| Skip platform detection at startup | Faster startup | Error spam on unsupported environments (WSL2, headless, SSH) | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| bash-preexec | Source it inside your plugin unconditionally | Check `$__bp_imported` first; tell users it must be sourced last |
| Zsh hook system | Call `precmd()` directly | Use `add-zsh-hook precmd your_function` |
| PulseAudio / PipeWire | Assume `aplay` works everywhere | Probe available tools at startup; degrade gracefully |
| WSL2 audio | Assume Linux = audio available | Detect WSL2 via `/proc/version` containing "microsoft"; disable audio silently |
| macOS audio | Assume `aplay` is available | Use `afplay` on macOS (detected via `$OSTYPE` or `uname`) |
| `PROMPT_COMMAND` (Bash) | Overwrite it directly | Append to it: `PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_bs_precmd"` |
| SSH headless sessions | Assume TTY always present | Check `[[ -t 1 ]]` before any visual output; check `[[ -t 2 ]]` before audio |
| User config file parsing | Use eval on config values | Parse strictly; never eval user-supplied strings |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Synchronous audio in hook | 100ms–5000ms prompt delay depending on sound length | Background all playback with `&` | Immediately on first use |
| Forking a subshell on every prompt | 5–20ms added to every prompt render | Cache results; use Zsh builtins instead of external commands | Every command, compounding on slow systems |
| Calling `command -v` to detect tools on every hook invocation | Measurable overhead per prompt | Detect tools once at plugin load; cache result in a variable | On every prompt cycle |
| Rendering spinner in foreground sleep loop | Blocks next command entry | Run spinner in background process; kill it in precmd | Any use of long-running commands |
| Watching stderr with a file descriptor redirect | Breaks stderr output for all commands | Use a targeted approach; measure impact carefully | From first implementation |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No way to mute audio | Users in meetings, shared spaces, or quiet environments cannot silence the plugin without uninstalling it | Provide `BETTER_SHELL_NO_AUDIO=1` env var AND `bs_mute` / `bs_unmute` CLI commands from day one |
| Sound plays on every single command | Rapid command execution (like a loop) produces a cacophony; users disable the plugin entirely | Play sounds only for commands exceeding a configurable duration threshold, or deduplicate rapid events |
| Audio too loud with no volume control | Startles users; embarrassing in open offices | Respect system volume; provide a volume/gain config option for supported tools |
| Visual effects appear in tmux/screen multiplexers | Cursor positioning escape codes corrupt rendering in split panes | Test in tmux; guard with `$TERM` detection; use line-relative positioning only |
| ASCII art breaks narrow terminal windows | Art wraps, looks broken, creates visual noise | Check `$COLUMNS` before rendering; have compact fallback for narrow terminals |
| No `NO_COLOR` support | Breaks usability for colorblind users, CI systems, and tools that strip ANSI | Honor `$NO_COLOR` (no value check needed — presence alone means disable color) |
| Plugin installs itself permanently | Users cannot try it without committing; no clean uninstall | Provide a documented uninstall procedure and an unload function |

---

## "Looks Done But Isn't" Checklist

- [ ] **Async audio:** Audio plays in background without `wait` — verify with `time echo hello` showing <5ms overhead after plugin load
- [ ] **Hook safety (Zsh):** Using `add-zsh-hook`, not `precmd()` — verify by loading alongside a prompt theme that also uses precmd
- [ ] **Hook safety (Bash):** Using `bash-preexec` function arrays, not raw `trap DEBUG` — verify by sourcing alongside iTerm2 shell integration
- [ ] **Non-interactive guard:** Plugin exits early when sourced non-interactively — verify with `bash -c 'source ~/.bashrc; echo done'` producing no garbage output
- [ ] **TTY guard:** No ANSI/visual output when stdout/stderr is not a TTY — verify with `source ~/.zshrc 2>&1 | cat` showing clean output
- [ ] **`NO_COLOR` support:** All color/ANSI output suppressed when `NO_COLOR` is set — verify with `NO_COLOR=1 zsh`
- [ ] **Audio tool fallback:** Plugin starts cleanly with no errors when no audio tool exists — verify in a minimal Docker container
- [ ] **WSL2 silence:** No error output on WSL2 without audio configured — verify or test with mocked missing audio tools
- [ ] **Namespace hygiene:** No bare function or variable names — verify with `typeset -f | grep -v "^_bs_\|^__bs_"` showing no unexpected functions
- [ ] **Zombie process cleanup:** No lingering audio processes after shell exit — verify with `ps aux | grep aplay` after closing terminal

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Blocking audio discovered post-release | LOW | Add `&` to all playback calls; patch release |
| Zsh hook overwrite (replacing precmd) | MEDIUM | Refactor to `add-zsh-hook`; requires testing full hook chain |
| DEBUG trap clobbering in Bash | MEDIUM | Integrate bash-preexec; audit all places where trap was set directly |
| Namespace collision discovered in wild | HIGH | Rename all variables and functions; breaking change for any user configs referencing internals |
| Non-interactive guard missing | MEDIUM | Add guard at top of plugin; test against known affected environments (CI, scripts) |
| Audio spam discovered in WSL2/SSH | LOW | Add environment detection; patch release |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Blocking hooks | Phase 1: Core hook infrastructure | `time echo hello` shows <5ms overhead with plugin loaded |
| DEBUG trap clobbering (Bash) | Phase 1: Core hook infrastructure | Source alongside bash-preexec and iTerm2 integration; both work |
| Zsh hook overwrite | Phase 1: Core hook infrastructure | Load alongside Starship or powerlevel10k; prompt theme intact |
| Namespace pollution | Phase 1: Foundation (before any code) | `typeset -f` and `typeset -p` show only prefixed names |
| Non-interactive / TTY guard | Phase 1: Foundation | `bash -c 'source ~/.bashrc'` in CI produces zero output |
| Audio tool detection / fallback | Phase 2: Audio integration | Plugin loads cleanly in Docker with no audio tools |
| WSL2 / headless audio silence | Phase 2: Audio integration | Manually test or mock missing audio environment |
| Visual output in pipes | Phase 3: Visual effects | `ls | cat` after plugin load shows no ANSI in piped output |
| NO_COLOR compliance | Phase 3: Visual effects | `NO_COLOR=1 zsh -i -c 'echo test'` shows no color codes |
| Async spinner cleanup | Phase 3: Visual effects | Background spinner is killed on precmd; no dangling processes |
| Zombie process accumulation | Phase 2+3: Audio + Visual | `ps aux` after 20 commands shows no orphaned playback processes |
| UX: no mute option | Phase 2: Audio integration | `BETTER_SHELL_NO_AUDIO=1` silences all audio before any feature ships |

---

## Sources

- [bash-preexec — DEBUG trap conflicts, PROMPT_COMMAND, multi-plugin issues](https://github.com/rcaloras/bash-preexec)
- [bash-preexec Issue #39 — Preserve existing DEBUG traps](https://github.com/rcaloras/bash-preexec/issues/39)
- [bash-preexec Conflicts with iTerm2 shell integration — Issue #21](https://github.com/rcaloras/bash-preexec/issues/21)
- [VSCode shell integration — DEBUG trap co-existence request](https://github.com/microsoft/vscode/issues/150241)
- [Amazon Q CLI Issue #844 — 11ms preexec hook causing performance complaints](https://github.com/aws/amazon-q-developer-cli/issues/844)
- [Zsh Plugin Standard — namespace, hook installation, unload functions](https://wiki.zshell.dev/community/zsh_plugin_standard)
- [NO_COLOR standard — environment variable for disabling ANSI color output](https://no-color.org/)
- [BashFAQ/105 — set -e (errexit) pitfalls and inconsistencies](https://mywiki.wooledge.org/BashFAQ/105)
- [BashPitfalls — comprehensive bash gotchas](https://mywiki.wooledge.org/BashPitfalls)
- [How to Write Better Bash Spinners — cursor management, raw mode](https://willcarh.art/blog/how-to-write-better-bash-spinners)
- [Untriggered traps in Zsh — trap behavior in subshells](https://monospacedmonologues.com/2020/07/untriggered-traps-in-zsh/)
- [XDG Base Directory Specification — config file placement conventions](https://wiki.archlinux.org/title/XDG_Base_Directory)
- [Getting sound to work on WSL2 — audio environment issues](https://discourse.ubuntu.com/t/getting-sound-to-work-on-wsl2/11869)
- [Zsh Plugin Standard — zdharma-continuum](https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html)

---
*Pitfalls research for: Shell plugin with audio/visual effects (Better Shell)*
*Researched: 2026-02-26*
