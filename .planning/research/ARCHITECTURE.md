# Architecture Research

**Domain:** Reactive shell plugin with audio/visual effects (bash/zsh)
**Researched:** 2026-02-26
**Confidence:** MEDIUM — hook mechanisms well-documented; cross-shell stderr capture and companion binary patterns verified via multiple real-world plugins; trigger/config system is novel and inferred from analogues.

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User Shell (bash/zsh)                        │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────────┐   │
│  │  preexec     │  │  precmd      │  │  PROMPT (PS1/RPROMPT)   │   │
│  │  (pre-cmd)   │  │  (post-cmd)  │  │  (prompt theming)       │   │
│  └──────┬───────┘  └──────┬───────┘  └─────────────────────────┘   │
│         │                 │                                           │
├─────────┴─────────────────┴───────────────────────────────────────── │
│                         Hook Dispatcher                               │
│   (sourced shell file — reads $?, records timing, reads command str) │
├───────────────────────────────────────────────────────────────────────┤
│                         Trigger Engine                                │
│   (evaluates rules: exit code, duration, command name, stderr flag)  │
├───────────────────────────────────────────────────────────────────────┤
│  ┌────────────────┐  ┌─────────────────┐  ┌───────────────────────┐ │
│  │  Audio Handler │  │  Visual Handler  │  │  Prompt Themer        │ │
│  │  (async &)     │  │  (spinner/art)   │  │  (PS1 mutation)       │ │
│  └────────┬───────┘  └────────┬─────────┘  └────────┬──────────────┘ │
│           │                   │                      │                │
├───────────┴───────────────────┴──────────────────────┴───────────────┤
│                      Companion Binary / Helper Script                  │
│      (non-shell program: plays audio, renders animations, parses cfg) │
├───────────────────────────────────────────────────────────────────────┤
│                         Config Layer                                   │
│     (YAML/TOML file + CLI write path → trigger→action mapping table)  │
└───────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| Hook Dispatcher | Intercepts preexec/precmd lifecycle events; captures $?, command string, timing | Sourced .sh/.zsh file using add-zsh-hook or bash-preexec arrays |
| Trigger Engine | Evaluates rules (exit code, elapsed time, stderr detected, command pattern) against config | Shell function that reads config at startup; pure shell logic or delegates to companion binary |
| Audio Handler | Plays sound files on matched events; must not block shell | `aplay`/`afplay`/`paplay` invoked as background process (`cmd &`) |
| Visual Handler | Shows ASCII art reactions, starts/stops spinner around long commands | Background subshell for spinner (killed in precmd); ASCII art printed inline |
| Prompt Themer | Mutates PS1/RPROMPT/PROMPT based on last exit code and theme config | Shell variable assignment inside precmd; ANSI escape codes |
| Companion Binary | Handles cross-platform audio dispatch, config file parsing, spinner rendering | Compiled binary (Go/Rust) or interpreted script (Python/Node) invoked by shell handlers |
| Config Layer | Maps trigger conditions to actions; persists user settings | YAML or TOML file on disk; CLI commands write to this file |

## Recommended Project Structure

```
better-shell/
├── better-shell.plugin.zsh   # Entry point: sources everything, registers hooks (zsh)
├── better-shell.bash         # Entry point for bash (sources bash-preexec, registers hooks)
├── lib/
│   ├── hooks.sh              # Hook registration logic (preexec/precmd functions)
│   ├── trigger.sh            # Trigger evaluation engine (reads config, matches rules)
│   ├── audio.sh              # Audio dispatch: platform detection + async invocation
│   ├── visual.sh             # ASCII art and spinner start/stop logic
│   ├── prompt.sh             # PS1/RPROMPT mutation functions
│   └── config.sh             # Config file loading, defaults, zstyle/env var parsing
├── bin/
│   └── better-shell          # Companion binary or script: audio, parsing, rendering
├── sounds/
│   ├── error.wav             # Default bundled sounds
│   ├── success.wav
│   └── README.md             # License info for bundled audio
├── art/
│   ├── error.txt             # Default ASCII art frames
│   └── success.txt
├── better-shell.conf.example # Documented example YAML/TOML config
└── README.md
```

### Structure Rationale

- **lib/:** Separate files per concern so each component can be tested, replaced, or stubbed independently. Sourced by entry points at load time.
- **bin/:** The companion binary lives outside shell code to handle things pure shell cannot (blocking audio, complex config parsing). It is invoked as a subprocess, never sourced.
- **sounds/ and art/:** Bundled defaults ship with the plugin so first-run works with zero config.
- **Two entry points (zsh/bash):** They share lib/ code but handle hook registration differently (zsh uses add-zsh-hook; bash uses bash-preexec's arrays).

## Architectural Patterns

### Pattern 1: Hook Array Registration

**What:** Instead of clobbering a single hook function (e.g., `precmd()`), append to hook arrays so multiple plugins coexist.
**When to use:** Always — this is the standard pattern for zsh (add-zsh-hook) and bash (bash-preexec arrays).
**Trade-offs:** Correct and composable; requires bash-preexec as a dependency for bash support.

**Example:**
```bash
# zsh
autoload -Uz add-zsh-hook
add-zsh-hook preexec _bsh_preexec
add-zsh-hook precmd  _bsh_precmd

# bash (via bash-preexec)
preexec_functions+=(_bsh_preexec)
precmd_functions+=(_bsh_precmd)
```

### Pattern 2: Async Audio via Background Process

**What:** Launch audio playback as a detached background process so the shell prompt returns immediately.
**When to use:** Any audio or slow I/O operation inside a hook.
**Trade-offs:** Non-blocking (correct behavior); no feedback if audio fails; concurrent sounds may overlap — mitigated by queuing in the companion binary.

**Example:**
```bash
_bsh_play_sound() {
  local file="$1"
  # Platform dispatch — completely non-blocking
  case "$(uname)" in
    Darwin) afplay "$file" & ;;
    Linux)
      if command -v paplay &>/dev/null; then paplay "$file" &
      elif command -v aplay &>/dev/null; then aplay "$file" &
      fi ;;
  esac
}
```

### Pattern 3: Spinner via Background Subshell

**What:** Start a spinner as a background loop in preexec; kill it by PID in precmd.
**When to use:** Long-running command visual feedback.
**Trade-offs:** Works in interactive shells; care needed to clean up PID if the shell crashes; spinner must clear its own terminal line on exit.

**Example:**
```bash
_BSH_SPINNER_PID=""

_bsh_preexec() {
  # Start spinner in background
  (_bsh_spinner_loop) &
  _BSH_SPINNER_PID=$!
  disown "$_BSH_SPINNER_PID"
}

_bsh_precmd() {
  local exit_code=$?
  # Stop spinner
  if [[ -n "$_BSH_SPINNER_PID" ]]; then
    kill "$_BSH_SPINNER_PID" 2>/dev/null
    wait "$_BSH_SPINNER_PID" 2>/dev/null
    printf "\r\033[2K"   # clear spinner line
    _BSH_SPINNER_PID=""
  fi
  # Then evaluate triggers with $exit_code
  _bsh_evaluate_triggers "$exit_code"
}
```

### Pattern 4: Exit Code + Timing Trigger Evaluation

**What:** Capture $? immediately in precmd before any other code can overwrite it; compute elapsed time from a timestamp saved in preexec; then evaluate trigger rules.
**When to use:** Core pattern for all reactive behavior.
**Trade-offs:** $? is fragile — it must be the very first thing captured in precmd. Elapsed time requires `$EPOCHSECONDS` (zsh) or `date +%s` (bash).

**Example:**
```bash
_BSH_CMD_START=0

_bsh_preexec() {
  _BSH_CMD_START=$EPOCHSECONDS  # zsh; use $(date +%s) for bash
}

_bsh_precmd() {
  local exit_code=$?                              # MUST be first
  local elapsed=$(( EPOCHSECONDS - _BSH_CMD_START ))
  _bsh_evaluate_triggers "$exit_code" "$elapsed"
}
```

### Pattern 5: Config-Driven Trigger Table

**What:** Define triggers as a table of (condition → action) pairs, loaded from a config file at plugin init time. Shell variables hold the parsed state.
**When to use:** Any user-customizable reactive behavior.
**Trade-offs:** Simple conditions can be parsed in shell; complex patterns (regex command matching, chained conditions) benefit from delegating parsing to the companion binary at load time.

**Example config (YAML):**
```yaml
triggers:
  - on: error
    play: sounds/error.wav
    show_art: art/error.txt
  - on: success
    play: sounds/success.wav
  - on: command_match
    pattern: "git push"
    play: sounds/deploy.wav
    min_duration: 5
```

## Data Flow

### Command Lifecycle Flow

```
User types command + hits Enter
    ↓
[preexec fires]
    ├── Record _BSH_CMD_START timestamp
    ├── Record command string
    └── Start spinner background process (store PID)

[Command executes]

[precmd fires]
    ├── Capture $? → exit_code   (FIRST — before anything else)
    ├── Compute elapsed time
    ├── Kill spinner (by PID) + clear line
    └── Call Trigger Engine
            ↓
    [Trigger Engine evaluates rules]
            ├── exit_code == 0?  → success triggers
            ├── exit_code != 0?  → error triggers
            ├── elapsed > threshold? → long-running triggers
            └── command matches pattern? → command-specific triggers
            ↓
    [For each matched trigger]
            ├── Audio Handler → async audio subprocess (&)
            ├── Visual Handler → print ASCII art inline
            └── Prompt Themer → set PS1/RPROMPT variables
                        ↓
                [Shell renders new prompt]
```

### Config Initialization Flow

```
Shell sources better-shell.plugin.zsh
    ↓
config.sh loads config file (YAML/TOML)
    ├── If companion binary available → delegate parsing → receive trigger table
    └── If no binary → fall back to shell-native defaults (env vars / zstyle)
    ↓
Trigger table stored in shell arrays/associative arrays
    ↓
Hook functions registered (add-zsh-hook / bash-preexec arrays)
    ↓
Plugin ready — zero overhead until next command executes
```

### Key Data Flows

1. **Exit code propagation:** $? flows from shell → precmd → Trigger Engine → matched handlers. Must never pass through a subshell or function call before capture.
2. **Audio dispatch:** Trigger Engine → audio.sh function → platform-specific tool (`aplay`/`afplay`) as background process. Shell does not wait for completion.
3. **Spinner lifecycle:** preexec stores PID → precmd kills PID → terminal line cleared → trigger evaluation runs. Spinner PID is a shell variable, not passed to subprocess.
4. **Config to triggers:** YAML/TOML file → companion binary parses → returns structured data → shell arrays at startup. Happens once at source time, not on every command.

## Scaling Considerations

This is a local developer tool — user scale (1, 10, 10K users) is irrelevant. The relevant "scaling" is performance under heavy use:

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single user, few triggers | Pure shell evaluation in precmd; no binary needed |
| Many triggers / regex matching | Delegate trigger matching to companion binary to avoid slow shell regex loops |
| High command frequency (scripts) | Disable plugin in non-interactive shells; guard with `[[ $- == *i* ]]` |

### Scaling Priorities

1. **First bottleneck:** Shell hook latency — precmd must complete in <10ms or users feel it. Keep trigger evaluation O(n) over rule count; cache parsed config.
2. **Second bottleneck:** Audio process spawn time — `afplay`/`aplay` startup adds ~50-100ms. Acceptable as background process; avoid synchronous invocation.

## Anti-Patterns

### Anti-Pattern 1: Overwriting precmd/preexec Directly

**What people do:** Define `precmd() { ... }` or `preexec() { ... }` directly in the plugin file.
**Why it's wrong:** Clobbers any other plugin or user code that registered the same hook. Only one definition wins.
**Do this instead:** Use `add-zsh-hook preexec _bsh_preexec` (zsh) or `preexec_functions+=(_bsh_preexec)` (bash). Arrays allow multiple registrations to coexist.

### Anti-Pattern 2: Capturing $? After Any Other Code

**What people do:** Run any code (even a variable assignment or function call) before reading $? in precmd.
**Why it's wrong:** $? is overwritten by the last executed command or function. If you check $? after killing the spinner, you get the exit code of `kill`, not the user's command.
**Do this instead:** `local exit_code=$?` must be the absolute first line of precmd, before spinner cleanup or anything else.

### Anti-Pattern 3: Synchronous Audio Playback

**What people do:** Call `aplay sound.wav` (without `&`) inside a hook.
**Why it's wrong:** Blocks the shell until audio finishes (typically 1-3 seconds). User cannot type the next command.
**Do this instead:** Always `aplay sound.wav &` or dispatch to a background process. The shell must return to the prompt immediately.

### Anti-Pattern 4: Sourcing or Running Companion Binary on Every Command

**What people do:** Invoke the companion binary for config parsing or trigger evaluation on every precmd call.
**Why it's wrong:** Process spawn cost (~5-50ms) is acceptable once at startup, but on every command it adds perceptible latency to every prompt.
**Do this instead:** Parse config at source time; store results in shell variables or arrays. Only invoke the binary for the actual side-effect action (play audio, render art), not for evaluation.

### Anti-Pattern 5: Using DEBUG Trap Directly for Cross-Shell Support

**What people do:** Implement their own DEBUG trap to get preexec behavior.
**Why it's wrong:** DEBUG trap behavior differs across bash, zsh, and ksh. It conflicts with other tools that use the same trap (e.g., debuggers, bash-preexec itself). ERR and DEBUG traps are not POSIX-defined.
**Do this instead:** Use bash-preexec for bash (it manages the DEBUG trap safely and handles conflicts) and add-zsh-hook for zsh. Accept that truly POSIX-portable sh cannot support these hooks.

### Anti-Pattern 6: Stderr Detection via Pipe Wrapper

**What people do:** Wrap the shell's command execution in a tee/pipe to detect if stderr was written to.
**Why it's wrong:** Requires changing how commands are invoked (breaking transparency), adds latency on every command, and interferes with interactive programs (vim, htop, fzf).
**Do this instead:** Detect errors via exit code only, which is always available in $? without interception. Document that stderr-as-error-signal requires a deliberate design choice with significant trade-offs.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| aplay (Linux ALSA) | Subprocess: `aplay -q file.wav &` | Requires ALSA userspace tools; `-q` suppresses stderr |
| paplay (PulseAudio/Pipewire) | Subprocess: `paplay file.wav &` | More common on modern Linux; check with `command -v` |
| afplay (macOS) | Subprocess: `afplay file.wav &` | Built-in on macOS; no install required |
| bash-preexec | Source at startup: `. bash-preexec.sh` | Must be sourced before the plugin registers its hooks |
| Shell plugin managers (antidote, zinit, sheldon) | Standard `plugin.zsh` naming; `autoload` for functions | Follow Zsh Plugin Standard naming conventions |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Hook Dispatcher ↔ Trigger Engine | Shell function call, passing exit_code + elapsed as args | Sync, in-process — must be fast |
| Trigger Engine ↔ Audio Handler | Shell function call, passing sound file path | Audio handler immediately goes async |
| Trigger Engine ↔ Visual Handler | Shell function call, passing art file or art type | Prints inline; spinner start/stop managed separately |
| Trigger Engine ↔ Prompt Themer | Shell variable mutation (PS1, RPROMPT) | Variables read by shell when rendering next prompt |
| Shell ↔ Companion Binary | subprocess exec with args; stdout parsed by shell | Companion binary must exit cleanly; shell checks exit code |
| Config Layer ↔ Trigger Engine | Shell associative arrays or indexed arrays populated at source time | No runtime I/O after init |

## Suggested Build Order

The components have clear dependencies. Build in this sequence:

1. **Hook Dispatcher** — Foundation. Registers preexec/precmd; proves hooks work in both bash and zsh. No logic yet, just `echo "preexec fired"` / `echo "precmd fired"`.

2. **Exit Code + Timing Capture** — Add $? capture and elapsed time calculation inside the hook dispatcher. Verify $? is correct before adding any other code.

3. **Config Layer (defaults only)** — Hard-code defaults (no file parsing). This lets components 4-6 be built against a fixed config shape before adding file I/O.

4. **Prompt Themer** — Pure shell, no subprocesses. Easiest feedback mechanism. Proves the hook lifecycle works end-to-end.

5. **Audio Handler** — Async subprocess dispatch. Platform detection. Test on both Linux and macOS. No config file yet — hard-code a test sound.

6. **Visual Handler (ASCII art)** — Print art inline in precmd. Then add spinner: background loop in preexec, kill in precmd.

7. **Trigger Engine** — Wire exit code, elapsed, and command string into rule evaluation. At this point all handlers exist; the engine routes to them.

8. **Config File Parsing** — Add YAML/TOML parsing (via companion binary or a shell-compatible format). Replace hard-coded defaults with file-loaded values.

9. **CLI Commands** — `better-shell add-trigger`, `better-shell list-triggers` etc. These write to the config file; the shell plugin reads it at next source.

10. **Companion Binary** — Extract heavy logic (config parsing, complex trigger matching, audio queuing) into the binary as the need for robustness becomes clear. Shell handlers remain thin wrappers.

## Sources

- bash-preexec (hook mechanism): https://github.com/rcaloras/bash-preexec/blob/master/README.md — MEDIUM confidence (GitHub README, widely used)
- zsh-notify plugin (audio/notification architecture): https://github.com/marzocchi/zsh-notify — MEDIUM confidence (real plugin, production use)
- ding plugin (audio zsh plugin file structure): https://github.com/jessetipton/ding — MEDIUM confidence (small plugin, well-documented)
- zsh-auto-notify (hook + cross-platform pattern): https://github.com/MichaelAquilina/zsh-auto-notify — MEDIUM confidence (production plugin)
- Spinner architecture: https://willcarh.art/blog/how-to-write-better-bash-spinners — MEDIUM confidence (technical article, verified pattern)
- bash-loading-animations: https://github.com/Silejonu/bash_loading_animations — MEDIUM confidence (GitHub project)
- POSIX trap limitations: https://www.shellcheck.net/wiki/SC3047 — HIGH confidence (ShellCheck official docs)
- Zsh hook system: https://zsh.sourceforge.io/Doc/Release/Functions.html — HIGH confidence (official zsh docs)
- Starship config/architecture (TOML config + module pattern): https://starship.rs/config/ — HIGH confidence (official docs)
- Hookbook (cross-shell hook compatibility): https://github.com/Shopify/hookbook — MEDIUM confidence (GitHub project)

---
*Architecture research for: reactive shell plugin with audio/visual effects (Better Shell)*
*Researched: 2026-02-26*
