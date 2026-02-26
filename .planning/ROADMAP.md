# Roadmap: Better Shell

## Overview

Better Shell is built in four phases that follow the natural dependency order of the system. Phase 1 establishes the safe hook foundation that all reactive behavior depends on. Phase 2 delivers the first user-visible feature — audio feedback. Phase 3 adds the core visual differentiator — ASCII art reactions and spinners. Phase 4 wires everything together with a config file, trigger rules, and CLI. The shell feels alive at the end of Phase 2; it becomes distinctly itself at the end of Phase 3; it becomes fully customizable at the end of Phase 4.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Hook Infrastructure** - Safe shell hooks that detect commands in bash and zsh without breaking anything (completed 2026-02-26)
- [ ] **Phase 2: Audio** - Non-blocking sound playback on error and success with cross-platform support
- [ ] **Phase 3: Visuals** - ASCII art reactions, animated spinners, and prompt exit code indicator
- [ ] **Phase 4: Config, Triggers, and CLI** - TOML config file, custom trigger rules, and CLI commands for setup

## Phase Details

### Phase 1: Hook Infrastructure
**Goal**: Users can source Better Shell into their rc file and have it silently detect command outcomes without disrupting any existing shell behavior
**Depends on**: Nothing (first phase)
**Requirements**: HOOK-01, HOOK-02, HOOK-03, HOOK-04
**Success Criteria** (what must be TRUE):
  1. User can add one `source` line to .bashrc or .zshrc and the plugin loads without errors
  2. Plugin fires preexec before commands and precmd after commands in both bash and zsh
  3. Plugin emits no output and adds no visible latency in non-interactive or piped contexts (SSH, CI, headless)
  4. User can run `bsh off` to suppress all plugin behavior and `bsh on` to restore it
**Plans:** 3/3 plans complete
Plans:
- [x] 01-01-PLAN.md — Core hook infrastructure: env detection, shell compat, preexec/precmd hooks
- [x] 01-02-PLAN.md — Toggle command (bsh on/off/status), config persistence, build distributable
- [ ] 01-03-PLAN.md — Gap closure: fix zsh early-exit bug in bash-preexec concatenation

### Phase 2: Audio
**Goal**: Users hear immediate, non-blocking audio feedback on command error and success, with sensible defaults that prevent noise on trivial commands
**Depends on**: Phase 1
**Requirements**: AUD-01, AUD-02, AUD-03, AUD-04, AUD-05, AUD-06, AUD-07, AUD-08, AUD-09, AUD-10
**Success Criteria** (what must be TRUE):
  1. Running a failing command (e.g., `ls /nonexistent`) plays an error sound without blocking the next prompt
  2. Running a successful command plays a success sound; trivial commands (under time threshold) play nothing
  3. Plugin works out of the box with bundled sounds — no user configuration required
  4. User can drop their own .wav or .mp3 file into config and hear it instead of the default
  5. Plugin detects and uses the available audio tool (afplay/aplay/paplay) and silently no-ops on systems with no audio
**Plans**: TBD

### Phase 3: Visuals
**Goal**: Users see ASCII art reactions and an animated spinner in their terminal, making the shell feel expressive and alive
**Depends on**: Phase 2
**Requirements**: VIS-01, VIS-02, VIS-03, VIS-04
**Success Criteria** (what must be TRUE):
  1. Running a failing command displays an ASCII art reaction inline in the terminal
  2. Running a successful command displays a different ASCII art reaction; each trigger shows a randomly selected variant
  3. Running a long command shows an animated spinner while it runs; the spinner disappears cleanly when the command finishes
  4. The prompt shows a colored checkmark or X indicating the last command's exit code
**Plans**: TBD

### Phase 4: Config, Triggers, and CLI
**Goal**: Users can customize every aspect of Better Shell's behavior through a TOML config file or quick CLI commands, including per-command trigger rules
**Depends on**: Phase 3
**Requirements**: CFG-01, CFG-02, CFG-03, CFG-04
**Success Criteria** (what must be TRUE):
  1. User can edit ~/.config/better-shell/config.toml and changes take effect on next shell source
  2. User can run `better-shell add-trigger --on error --play custom.wav` and the trigger fires on next failing command
  3. User can define a rule that plays a specific sound only when `git push` succeeds
  4. Any setting reachable via CLI can also be set in the config file and vice versa
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Hook Infrastructure | 3/3 | Complete   | 2026-02-26 |
| 2. Audio | 0/? | Not started | - |
| 3. Visuals | 0/? | Not started | - |
| 4. Config, Triggers, and CLI | 0/? | Not started | - |
