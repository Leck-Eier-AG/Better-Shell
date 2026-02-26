# Phase 1: Hook Infrastructure - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Safe shell hooks that detect command start, end, and exit code in bash and zsh. Users source one line in their rc file and the plugin silently monitors command outcomes without disrupting existing shell behavior. No audio, no visuals — just the hook foundation that all later phases build on.

</domain>

<decisions>
## Implementation Decisions

### Installation & file layout
- Install via git clone to `~/.better-shell/`
- Entry point: `source ~/.better-shell/better-shell.sh`
- Modular source structure with `lib/` directory (lib/hooks.sh, etc.)
- Concatenation build step: develop in separate files, build into single distributable script
- User adds one `source` line to .bashrc or .zshrc

### Safety & environment detection
- Non-interactive environments (CI, piped, headless): silent no-op — don't load hooks at all, zero output
- SSH sessions: disabled by default, but user can enable specific features via config
- Internal errors: silently disable the plugin for the session and continue — the shell must never break
- Existing hooks: chain with them — detect if preexec/precmd are already defined, save reference, call them after Better Shell's hook runs. Never clobber user hooks

### Toggle UX
- Commands: `bsh on` / `bsh off` / `bsh status`
- `bsh off` is session-only by default; `bsh off --persist` writes to config file
- `bsh on` restores plugin for session; `bsh on --persist` clears persistent disable
- Toggle feedback: short one-line confirmation ("Better Shell: off" / "Better Shell: on")
- `bsh status` shows: enabled/disabled, detected shell, detected audio tool, active theme

### Language & dependencies
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

</decisions>

<specifics>
## Specific Ideas

- The `bsh` namespace was chosen for brevity — all user-facing commands go through `bsh`
- Concatenation build means users can either clone and build, or just source the pre-built file
- SSH config override suggests a simple config mechanism is needed even in Phase 1 (at minimum, reading a config file for SSH behavior)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-hook-infrastructure*
*Context gathered: 2026-02-26*
