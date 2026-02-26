# Phase 1: Hook Infrastructure - Research

**Researched:** 2026-02-26
**Domain:** Shell hook infrastructure (bash/zsh), plugin architecture, environment detection
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Installation & file layout
- Install via git clone to `~/.better-shell/`
- Entry point: `source ~/.better-shell/better-shell.sh`
- Modular source structure with `lib/` directory (lib/hooks.sh, etc.)
- Concatenation build step: develop in separate files, build into single distributable script
- User adds one `source` line to .bashrc or .zshrc

#### Safety & environment detection
- Non-interactive environments (CI, piped, headless): silent no-op — don't load hooks at all, zero output
- SSH sessions: disabled by default, but user can enable specific features via config
- Internal errors: silently disable the plugin for the session and continue — the shell must never break
- Existing hooks: chain with them — detect if preexec/precmd are already defined, save reference, call them after Better Shell's hook runs. Never clobber user hooks

#### Toggle UX
- Commands: `bsh on` / `bsh off` / `bsh status`
- `bsh off` is session-only by default; `bsh off --persist` writes to config file
- `bsh on` restores plugin for session; `bsh on --persist` clears persistent disable
- Toggle feedback: short one-line confirmation ("Better Shell: off" / "Better Shell: on")
- `bsh status` shows: enabled/disabled, detected shell, detected audio tool, active theme

#### Language & dependencies
- Target bash 4+ and zsh (no POSIX-only constraint)
- Use bash/zsh features freely: arrays, local vars, [[ ]], etc.
- External dependencies: Claude's discretion per feature (audio playback will need system tools)
- Concatenation build: modular development files → single distributable script

### Claude's Discretion
- Exact hook implementation mechanism (bash-preexec vs custom DEBUG trap vs other)
- Internal code organization within lib/ modules
- Build tool choice for concatenation step
- How to handle `bsh` command routing (function vs script on PATH)
- Specific environment detection heuristics beyond SSH

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| HOOK-01 | Shell hooks (preexec/precmd) detect command start, end, and exit code across bash and zsh | bash-preexec library for bash; native add-zsh-hook for zsh; exit code capture pattern documented |
| HOOK-02 | Plugin installs via single `source` line in rc file | Entry point `better-shell.sh` sources lib/ files; shell detection dispatches to bash or zsh path |
| HOOK-03 | Auto-detect SSH/headless/CI environments and disable audio/visuals | Multi-check guard: `[[ $- != *i* ]]`, `SSH_TTY`, `CI`, `GITHUB_ACTIONS`, `tty -s` |
| HOOK-04 | Global enable/disable toggle via command and config | `bsh` dispatcher function; `_BSH_ENABLED` variable guard; config file for `--persist` flag |
</phase_requirements>

---

## Summary

This phase implements the silent foundation that all subsequent phases depend on. The core problem is detecting when a command starts and ends in both bash and zsh, capturing the exit code, and doing this without any visible side effects — no output, no latency in non-interactive contexts, no clobbering of existing hook registrations from other shell plugins.

Bash and zsh have asymmetric hook systems. Zsh has native `preexec` and `precmd` hooks with a well-designed `add-zsh-hook` utility that allows multiple plugins to coexist cleanly. Bash has no native preexec — the traditional approach uses a `DEBUG` trap plus `PROMPT_COMMAND`, which has significant pitfalls. The recommended solution is to use **bash-preexec** (github.com/rcaloras/bash-preexec) as a bundled dependency for bash, while using native `add-zsh-hook` for zsh. This gives a clean, consistent API (`preexec_functions`/`precmd_functions` arrays) in both shells.

The `bsh` toggle command is a shell function (not a separate script on PATH) that manipulates a `_BSH_ENABLED` variable and removes/restores functions from the hook arrays. A minimal config file at `~/.better-shell/config` handles `--persist` behavior using simple `key=value` parsing — no external tools needed.

**Primary recommendation:** Use bash-preexec (bundled) for bash hook infrastructure; use `add-zsh-hook` natively for zsh. Implement the `bsh` dispatcher as a single shell function that routes subcommands. Gate all hook behavior behind a fast `[[ $_BSH_ENABLED == 1 ]]` check at the top of every hook function.

---

## Standard Stack

### Core

| Component | Version/Source | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| bash-preexec | 0.6.0 (bundle in repo) | preexec/precmd hooks for bash | Only mature solution; used by iTerm2, Ghostty, Bashhub; handles DEBUG trap edge cases |
| zsh `add-zsh-hook` | Built-in (zsh 5.3+) | Register preexec/precmd hooks in zsh | Official zsh API; allows multiple plugins to coexist; no chaining logic needed |
| GNU Make | System make | Build step: concatenate lib/ files into distributable | Zero dependencies; one-liner concatenation recipe |

### Supporting

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `$preexec_functions` array | Register preexec callbacks (bash via bash-preexec, zsh native) | Both shells — uniform interface |
| `$precmd_functions` array | Register precmd callbacks | Both shells — uniform interface |
| `~/.better-shell/config` | Persist enable/disable state across sessions | Only for `bsh off --persist` / `bsh on --persist` |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bash-preexec (bundled) | Custom DEBUG trap | DEBUG trap fires excessively, conflicts with other tools (VSCode, direnv, oh-my-posh); bash-preexec already solved this |
| bash-preexec (bundled) | Bash 5.3+ native PS0 | PS0 approach only works on bash 5.3+; bash 4+ is the stated target |
| GNU Make build | Shell script concatenation | Both work; Makefile is more conventional and provides `make build` / `make clean` targets |
| Shell function `bsh` | Script on PATH | Shell function is simpler, available immediately after source, no PATH dependency |

**Installation:**
```bash
# bash-preexec bundled in repo — no user installation needed
# Build step:
make build  # or: cat lib/header.sh lib/env.sh lib/hooks.sh lib/toggle.sh lib/config.sh > better-shell.sh
```

---

## Architecture Patterns

### Recommended Project Structure

```
~/.better-shell/
├── better-shell.sh      # Built distributable (the file users source)
├── config               # User config file (key=value, created on first persist)
├── Makefile             # Build: cat lib/* > better-shell.sh
└── lib/
    ├── header.sh        # Shebang comment, version var, idempotency guard
    ├── env.sh           # Environment detection (interactive check, SSH, CI)
    ├── compat.sh        # Shell detection, bash-preexec sourcing for bash
    ├── hooks.sh         # preexec_bsh() and precmd_bsh() implementations
    ├── toggle.sh        # bsh() dispatcher function (on/off/status subcommands)
    └── config.sh        # Config file read/write helpers
```

Development tree (source of truth):
```
better-shell/
├── better-shell.sh      # Built output (gitignored or committed after build)
├── Makefile
├── lib/
│   ├── header.sh
│   ├── env.sh
│   ├── compat.sh
│   ├── hooks.sh
│   ├── toggle.sh
│   └── config.sh
└── vendor/
    └── bash-preexec.sh  # Pinned version of bash-preexec
```

### Pattern 1: Idempotency Guard (prevent double-source)

**What:** A variable check at the top of the entry point that returns immediately if already loaded.
**When to use:** Always — users may source from both .bashrc and .zshrc, or have duplicate source lines.

```bash
# Source: standard shell plugin pattern
[[ -n "${_BSH_LOADED:-}" ]] && return 0
_BSH_LOADED=1
```

### Pattern 2: Interactive Environment Detection

**What:** Multi-check guard that exits early in non-interactive contexts.
**When to use:** First thing after the idempotency guard — before any hook registration.

```bash
# Source: bash manual + common shell plugin patterns (nixCraft, bash-preexec source)
_bsh_is_interactive() {
  # Bash: $- contains 'i' for interactive shells
  # Zsh: $- also works, or use [[ -o interactive ]]
  [[ $- == *i* ]] || return 1

  # No TTY attached (piped, CI, non-interactive scripts)
  [[ -t 1 ]] || return 1

  # SSH: disabled by default unless config says otherwise
  if [[ -n "${SSH_TTY:-}" || -n "${SSH_CLIENT:-}" ]]; then
    [[ "${_BSH_SSH_ENABLED:-0}" == "1" ]] || return 1
  fi

  # Known CI environments
  if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${JENKINS_URL:-}" ]]; then
    return 1
  fi

  return 0
}
```

### Pattern 3: Hook Registration with Chaining

**What:** Register Better Shell hooks using arrays, never overwriting existing hooks.
**When to use:** After environment detection passes. Both bash (via bash-preexec) and zsh use the same `_functions` array API.

```bash
# Source: bash-preexec README + zsh official docs
# Zsh:
autoload -Uz add-zsh-hook
add-zsh-hook preexec _bsh_preexec
add-zsh-hook precmd _bsh_precmd

# Bash (after bash-preexec is sourced):
preexec_functions+=(_bsh_preexec)
precmd_functions+=(_bsh_precmd)
```

This never clobbers existing hooks — `add-zsh-hook` appends to the array, and `+=` on bash-preexec's arrays appends without overwriting.

### Pattern 4: Exit Code Capture

**What:** Capture `$?` as the very first statement in the precmd function.
**When to use:** Always — any operation before the capture will overwrite `$?`.

```bash
# Source: bash-preexec docs + zsh hooks documentation
_bsh_precmd() {
  local _bsh_exit_code=$?   # MUST be first — captures previous command's exit code
  [[ $_BSH_ENABLED == 1 ]] || return 0
  # ... rest of precmd logic uses $_bsh_exit_code
}
```

Note: In zsh, when using `precmd_functions` array, each function receives the same `$?` value (the exit code of the last command). In bash via bash-preexec, same behavior applies.

### Pattern 5: Toggle via Variable Guard

**What:** A `_BSH_ENABLED` variable that all hook functions check before doing anything.
**When to use:** All hook functions, plus the `bsh` dispatcher.

```bash
# Session toggle — fast path
_BSH_ENABLED=1

_bsh_preexec() {
  [[ $_BSH_ENABLED == 1 ]] || return 0
  # ... do work
}

bsh() {
  case "${1:-}" in
    on)
      _BSH_ENABLED=1
      [[ "${2:-}" == "--persist" ]] && _bsh_config_set "enabled" "1"
      echo "Better Shell: on"
      ;;
    off)
      _BSH_ENABLED=0
      [[ "${2:-}" == "--persist" ]] && _bsh_config_set "enabled" "0"
      echo "Better Shell: off"
      ;;
    status)
      _bsh_print_status
      ;;
    *)
      echo "Usage: bsh on|off|status [--persist]" >&2
      ;;
  esac
}
```

### Pattern 6: Minimal Config File

**What:** A `~/.better-shell/config` file with `key=value` lines, parsed entirely in shell.
**When to use:** For `--persist` flag behavior and SSH opt-in.

```bash
# Write:
_bsh_config_set() {
  local key="$1" value="$2"
  local config="${_BSH_DIR}/config"
  # Remove existing line, append new one
  if [[ -f "$config" ]]; then
    local tmp
    tmp=$(grep -v "^${key}=" "$config")
    printf '%s\n%s=%s\n' "$tmp" "$key" "$value" > "$config"
  else
    printf '%s=%s\n' "$key" "$value" > "$config"
  fi
}

# Read at load time:
_bsh_config_load() {
  local config="${_BSH_DIR}/config"
  [[ -f "$config" ]] || return 0
  while IFS='=' read -r key value; do
    [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue  # safety: skip malformed lines
    case "$key" in
      enabled)      _BSH_ENABLED="$value" ;;
      ssh_enabled)  _BSH_SSH_ENABLED="$value" ;;
    esac
  done < "$config"
}
```

### Pattern 7: Shell Detection

**What:** Detect bash vs zsh at load time and set up the appropriate hook path.
**When to use:** In `compat.sh` / entry point after interactive check.

```bash
# Source: standard shell detection idiom
if [[ -n "${ZSH_VERSION:-}" ]]; then
  _BSH_SHELL="zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
  _BSH_SHELL="bash"
else
  # Unknown shell — silently bail
  return 0
fi
```

### Pattern 8: bash-preexec Bundling

**What:** Bundle vendor/bash-preexec.sh inside the repo; source it from better-shell.sh at build time (concatenated in) or at runtime.
**When to use:** Bash path only.

```bash
# In compat.sh (bash branch):
if [[ "$_BSH_SHELL" == "bash" ]]; then
  # Source bundled bash-preexec (concatenated into better-shell.sh at build time)
  # bash-preexec uses deferred install — safe to source before rc file is done
  # It must appear before our preexec_functions+=() calls, not necessarily last in rc
  _bsh_load_bash_preexec
fi
```

Important: bash-preexec's deferred install mechanism (`__bp_install_after_session_init`) works by appending to PROMPT_COMMAND and executing `__bp_install` on the first prompt. This means it self-installs after the rc file finishes loading — the "source last" requirement is about ensuring other PROMPT_COMMAND modifications are captured, but the deferred mechanism handles this automatically in most cases.

### Anti-Patterns to Avoid

- **Overwriting preexec/precmd directly:** Defining `preexec() { ... }` clobbers any existing function of that name. Always use the `_functions` array APIs.
- **Relying on PS1 for interactive detection:** PS1 can be set by users in non-interactive scripts. Use `[[ $- == *i* ]]` and `[[ -t 1 ]]` together.
- **Using `echo` in hook functions unconditionally:** Any unexpected output from hook functions will corrupt piped commands, scripts that capture shell output, and CI environments.
- **Writing config file with `>` redirect without locking:** Race conditions are unlikely in interactive use but bad practice. Use temp-file-then-move for atomicity.
- **Capturing exit code late:** Any comparison, assignment, or function call before `local _bsh_exit_code=$?` will overwrite `$?`. It must be the first line.
- **Setting `extdebug` or `functrace` globally:** bash-preexec disables these by default for good reason — they cause DEBUG trap to fire in subshells, massively degrading performance.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| bash preexec hook | Custom DEBUG trap implementation | bash-preexec (bundled vendor/) | DEBUG trap fires before every simple command, pipeline stage, and subshell — requires complex state machine to fire only once per user-typed command. bash-preexec already solved this in ~300 lines with years of edge case fixes |
| zsh hook chaining | Manually save/restore preexec function | `add-zsh-hook` builtin | Native API guarantees correct array management and handles removal cleanly |
| Multiple hook coexistence | Custom hook dispatcher | `preexec_functions+=()` / `add-zsh-hook` append | Both APIs are additive by design — appending never breaks existing hooks |

**Key insight:** The DEBUG trap in bash looks simple but the edge cases (subshells, pipelines, `COMP_POINT`, `READLINE_POINT`, functrace interactions) are the reason bash-preexec is ~300 lines of carefully tested code. Building a custom implementation will miss these cases and break in non-obvious ways.

---

## Common Pitfalls

### Pitfall 1: bash-preexec "Source Last" Requirement

**What goes wrong:** If better-shell sources bash-preexec and other tools (starship, direnv, oh-my-posh) also manipulate PROMPT_COMMAND after it, the hook ordering can break.
**Why it happens:** bash-preexec installs via PROMPT_COMMAND. Tools that do `PROMPT_COMMAND=("${PROMPT_COMMAND[@]}")` (array assignment overwrite) instead of `PROMPT_COMMAND+=()` will clear bash-preexec's hooks.
**How to avoid:** The deferred install mechanism (`__bp_install_after_session_init`) handles most cases. Document in install instructions that better-shell's source line should be last (or near last) in .bashrc.
**Warning signs:** preexec hook never fires; PROMPT_COMMAND is non-array after install.

### Pitfall 2: Exit Code Clobbered Before Capture

**What goes wrong:** `precmd` records exit code 0 for every command.
**Why it happens:** Any function call, `[[ ]]` test, or variable assignment before `local _bsh_exit_code=$?` resets `$?` to 0 or the result of that operation.
**How to avoid:** `local _bsh_exit_code=$?` is always the very first statement in `_bsh_precmd()`, before the enabled guard, before anything else.
**Warning signs:** AUD-01 (error sound) never triggers even when commands fail.

### Pitfall 3: Hook Output in Non-Interactive Contexts

**What goes wrong:** Running `bash -c 'some command'` or piping to bash produces unexpected output from plugin hooks.
**Why it happens:** Hooks are sourced into all bash instances if .bashrc is not guarded.
**How to avoid:** The interactive guard (`[[ $- == *i* ]] && [[ -t 1 ]]`) at the very top of better-shell.sh returns before any function definition or hook registration.
**Warning signs:** `echo "cmd" | bash` produces output not from the command; CI pipelines see unexpected text on stderr.

### Pitfall 4: Conflicts with Other Shell Integrations

**What goes wrong:** bash-preexec conflicts with other DEBUG trap users (VSCode shell integration, oh-my-posh, iTerm2 shell integration if using old-style traps).
**Why it happens:** Multiple tools each try to own the DEBUG trap and PROMPT_COMMAND.
**How to avoid:** bash-preexec preserves existing DEBUG traps by wrapping them into the `preexec_functions` array. The conflict usually happens when the *other* tool overwrites bash-preexec's trap after the fact. This is the other tool's problem, but document it.
**Warning signs:** Users report hooks stop working after installing other terminal tools.

### Pitfall 5: SSH Session Handling

**What goes wrong:** SSH sessions ARE interactive (they have a TTY, `$-` contains `i`), so the basic interactive check does not filter them.
**Why it happens:** SSH login shells pass the interactive check. CI systems like GitHub Actions that SSH into runners also pass.
**How to avoid:** Explicitly check `SSH_TTY` and `SSH_CLIENT` variables and only load if config opt-in is present. Note: `SSH_TTY` is set for interactive SSH, `SSH_CLIENT` is set for all SSH connections including non-interactive.
**Warning signs:** Plugin loads on SSH sessions when it shouldn't; users running `ssh user@host some-command` see unexpected behavior.

### Pitfall 6: Zsh `emulate -L zsh` in Hook Functions

**What goes wrong:** zsh hook functions called from frameworks that set unusual options (e.g., `emulate sh`) inherit those options, breaking `[[ ]]` or other zsh-isms.
**Why it happens:** zsh option inheritance across autoloaded functions.
**How to avoid:** Add `emulate -L zsh` at the top of zsh-specific hook functions to reset to known-good zsh defaults.
**Warning signs:** Syntax errors in hook functions only when using certain zsh frameworks (prezto, zi).

---

## Code Examples

### Complete Entry Point Structure

```bash
# better-shell.sh (built from lib/* via make build)
# Source: synthesized from bash-preexec README + zsh plugin standard patterns

# 1. Idempotency guard
[[ -n "${_BSH_LOADED:-}" ]] && return 0
_BSH_LOADED=1

# 2. Locate plugin directory
_BSH_DIR="${_BSH_DIR:-${HOME}/.better-shell}"

# 3. Interactive environment check — bail silently if non-interactive
[[ $- == *i* ]] || return 0
[[ -t 1 ]] || return 0

# 4. Shell detection
if [[ -n "${ZSH_VERSION:-}" ]]; then
  _BSH_SHELL="zsh"
elif [[ -n "${BASH_VERSION:-}" ]]; then
  _BSH_SHELL="bash"
else
  return 0
fi

# 5. Load config (sets _BSH_ENABLED, _BSH_SSH_ENABLED)
_BSH_ENABLED=1
_BSH_SSH_ENABLED=0
# ... _bsh_config_load function and call here ...

# 6. SSH check (after config load, since config can enable SSH)
if [[ -n "${SSH_TTY:-}" || -n "${SSH_CLIENT:-}" ]]; then
  [[ "${_BSH_SSH_ENABLED:-0}" == "1" ]] || return 0
fi

# 7. Register hooks
if [[ "$_BSH_SHELL" == "zsh" ]]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook preexec _bsh_preexec
  add-zsh-hook precmd  _bsh_precmd
else
  # bash: bash-preexec was concatenated into this file above
  preexec_functions+=(_bsh_preexec)
  precmd_functions+=(_bsh_precmd)
fi
```

### preexec Implementation

```bash
# Source: synthesized from bash-preexec docs + zsh docs
# $1 = the command string typed by the user (bash-preexec and zsh both pass this)
_bsh_preexec() {
  [[ $_BSH_ENABLED == 1 ]] || return 0
  _BSH_CMD_START_TIME=$SECONDS  # bash/zsh both have $SECONDS
  _BSH_LAST_CMD="${1:-}"
}
```

### precmd Implementation

```bash
# Source: synthesized from bash-preexec docs + zsh docs
_bsh_precmd() {
  local _bsh_exit=$?    # MUST be first
  [[ $_BSH_ENABLED == 1 ]] || return 0
  _BSH_LAST_EXIT=$_bsh_exit
  # Duration calculation for phase 2 (threshold filtering)
  _BSH_CMD_DURATION=$(( SECONDS - ${_BSH_CMD_START_TIME:-SECONDS} ))
  _BSH_CMD_START_TIME=$SECONDS
  # Phase 2+ will act on _BSH_LAST_EXIT and _BSH_CMD_DURATION here
}
```

### Build System (Makefile)

```makefile
# Source: standard shell project Makefile pattern
DIST := better-shell.sh
LIB  := lib/header.sh lib/env.sh lib/compat.sh lib/hooks.sh lib/toggle.sh lib/config.sh
VENDOR := vendor/bash-preexec.sh

.PHONY: build clean

build:
	cat $(VENDOR) $(LIB) > $(DIST)

clean:
	rm -f $(DIST)
```

This produces a single `better-shell.sh` where bash-preexec is pre-bundled and all lib/ files are inlined.

### bsh Dispatcher Function

```bash
# Source: synthesized from standard shell dispatch pattern
bsh() {
  local subcmd="${1:-}"
  local flag="${2:-}"

  case "$subcmd" in
    on)
      _BSH_ENABLED=1
      if [[ "$flag" == "--persist" ]]; then
        _bsh_config_set "enabled" "1"
      fi
      printf 'Better Shell: on\n'
      ;;
    off)
      _BSH_ENABLED=0
      if [[ "$flag" == "--persist" ]]; then
        _bsh_config_set "enabled" "0"
      fi
      printf 'Better Shell: off\n'
      ;;
    status)
      local state
      [[ $_BSH_ENABLED == 1 ]] && state="enabled" || state="disabled"
      printf 'Better Shell: %s\n' "$state"
      printf '  Shell: %s\n' "${_BSH_SHELL:-unknown}"
      printf '  Audio: %s\n' "${_BSH_AUDIO_TOOL:-not detected}"  # Phase 2
      printf '  Theme: %s\n' "${_BSH_THEME:-default}"            # Phase 3
      ;;
    *)
      printf 'Usage: bsh on|off|status [--persist]\n' >&2
      return 1
      ;;
  esac
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Custom DEBUG trap for bash preexec | bash-preexec library (bundled) | ~2015, mature | Eliminates months of edge case debugging |
| `PROMPT_COMMAND="func; $PROMPT_COMMAND"` | `precmd_functions+=()` via bash-preexec | bash-preexec adoption | Multiple tools coexist without conflict |
| Direct `preexec()` function overwrite in zsh | `add-zsh-hook preexec funcname` | zsh 5.0+ | Multiple plugins coexist; hook removal possible |
| Checking only `$PS1` for interactivity | Multi-check: `$-`, `tty`, `SSH_TTY`, `CI` vars | Ongoing practice evolution | Fewer false positives in edge environments |
| Bash 5.3+ native PS0 preexec | Still emerging, not yet standard | bash 5.3 released Dec 2023 | Not yet viable for bash 4+ target |

**Deprecated/outdated:**
- `trap 'preexec_logic' DEBUG` as primary mechanism: Fires on every subcommand in a pipeline, before completions, in subshells — not actually "one per user command". Use bash-preexec instead.
- Setting `PROMPT_COMMAND` by overwrite (`PROMPT_COMMAND="my_func"`) instead of append: Destroys other tools' hooks. Always use `+=`.

---

## Open Questions

1. **bash-preexec "source last" in practice**
   - What we know: bash-preexec's deferred install mechanism handles most cases; the "source last" requirement is about capturing all PROMPT_COMMAND modifications
   - What's unclear: Do we need to document this strongly for users, or does the deferred mechanism make it essentially transparent?
   - Recommendation: Plan for documentation in the install instructions. In the entry point, add a comment. During Phase 1 testing, verify with a .bashrc that has direnv and starship already configured.

2. **Makefile vs shell script for build**
   - What we know: Both work; Makefile is conventional; user explicitly left this to Claude's discretion
   - What's unclear: Nothing technical — it's a style choice
   - Recommendation: Use `Makefile` with `make build` target. It's a familiar interface and allows future `make test` / `make install` targets.

3. **bash-preexec bundling strategy**
   - What we know: bash-preexec 0.6.0 is the current version; can be bundled via `vendor/bash-preexec.sh`
   - What's unclear: Whether to concatenate it into `better-shell.sh` at build time (clean for users) vs source it at runtime (easier updates)
   - Recommendation: Concatenate at build time into `better-shell.sh`. Users source one file with no separate vendor dependency at runtime. Update vendor file and rebuild to upgrade.

---

## Sources

### Primary (HIGH confidence)
- https://github.com/rcaloras/bash-preexec — README and source code reviewed: installation, deferred install mechanism, preexec_functions/precmd_functions arrays, non-interactive guards, DEBUG trap preservation
- https://zsh.sourceforge.io/Doc/Release/Functions.html — official zsh docs: preexec/precmd hook specification, precmd_functions array, behavior guarantees
- https://github.com/zsh-users/zsh/blob/master/Functions/Misc/add-zsh-hook — official add-zsh-hook source: append semantics confirmed

### Secondary (MEDIUM confidence)
- https://posix.nexus/posts/native-bash-preexec/ — bash 5.3 PS0 approach, verified against bash 5.3 release notes; establishes why bash-preexec is still appropriate for bash 4+ target
- https://jichu4n.com/posts/debug-trap-and-prompt_command-in-bash/ — DEBUG trap + PROMPT_COMMAND interaction details (fetch timed out, but findings corroborated by bash-preexec source code and GitHub issues)
- https://github.com/rothgar/mastering-zsh/blob/master/docs/config/hooks.md — zsh hooks overview, add-zsh-hook usage
- https://www.cyberciti.biz/faq/linux-unix-bash-check-interactive-shell/ — interactive detection methods ($-, PS1, tty)

### Tertiary (LOW confidence)
- GitHub issues: bash-preexec conflicts with direnv, oh-my-posh — patterns are consistent across multiple issues; specific reproduction steps not independently verified
- https://zdharma-continuum.github.io/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html — zsh plugin standard (fetch timed out); naming conventions noted from search summary only

---

## Metadata

**Confidence breakdown:**
- Hook mechanism (bash-preexec + add-zsh-hook): HIGH — source code and README reviewed directly
- Exit code capture pattern: HIGH — documented in bash-preexec and zsh official docs
- Environment detection heuristics: HIGH — $-, tty, SSH_TTY, CI are well-established variables
- Pitfalls (conflicts, DEBUG trap): HIGH — corroborated by bash-preexec source + multiple GitHub issues
- Build system (Makefile concatenation): HIGH — standard UNIX pattern, no library uncertainty
- Config file parsing pattern: MEDIUM — standard shell practice, not verified against a specific reference

**Research date:** 2026-02-26
**Valid until:** 2026-05-26 (bash-preexec and zsh hook APIs are stable; 90-day validity)
