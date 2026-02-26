---
phase: 01-hook-infrastructure
plan: 02
subsystem: infra
tags: [bash, zsh, toggle, config, bsh, shell-plugin, persistence]

# Dependency graph
requires:
  - phase: 01-hook-infrastructure/01-01
    provides: lib/header.sh (_BSH_DIR, _BSH_ENABLED, _BSH_SSH_ENABLED), lib/env.sh, lib/compat.sh, lib/hooks.sh, vendor/bash-preexec.sh, Makefile
provides:
  - lib/config.sh: _bsh_config_load (key=value reader with injection safety), _bsh_config_set (atomic write)
  - lib/toggle.sh: bsh() public dispatcher (on/off/status + --persist), _bsh_print_status()
  - better-shell.sh: built 636-line distributable — single file users source
  - tests/test_toggle.sh: 14-test TAP suite for toggle and config layer
  - .gitignore: editor/OS files and runtime config file ignored
affects:
  - Phase 2 (audio/visual triggers build on _BSH_LAST_EXIT/_BSH_CMD_DURATION, can use bsh status)
  - Phase 3 (themes will set _BSH_THEME, visible in bsh status)
  - Phase 4 (config file will hold trigger rules once TOML is added)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - atomic config write via tmp.PID then mv (prevents corruption)
    - key=value config with regex safety check (^[a-zA-Z_][a-zA-Z0-9_]*$)
    - config loaded at source time — persisted state overrides defaults before gate
    - public API function without underscore prefix (bsh, not _bsh)

key-files:
  created:
    - lib/config.sh
    - lib/toggle.sh
    - better-shell.sh
    - tests/test_toggle.sh
    - .gitignore
  modified:
    - Makefile

key-decisions:
  - "config.sh sourced before env.sh so persisted ssh_enabled overrides default before the interactive gate"
  - "Atomic write for _bsh_config_set: write to ${config}.tmp.${PID} then mv — prevents config corruption on crash"
  - "better-shell.sh tracked in git so users get working plugin immediately after git clone without needing make"
  - "bsh function is public API (no underscore prefix); all helpers remain _bsh_ prefixed"
  - "_bsh_config_load called automatically at bottom of config.sh — persisted disable survives new sessions"

patterns-established:
  - "Key=value config: simple line format, regex key validation, unknown keys ignored (forward-compatible)"
  - "Dispatcher pattern: bsh() case statement with subcmd + flag; invalid subcommand prints Usage to stderr, returns 1"
  - "Status function: _bsh_print_status uses printf for portability; includes placeholders for Phase 2/3 vars"

requirements-completed: [HOOK-04]

# Metrics
duration: 2min
completed: 2026-02-26
---

# Phase 1 Plan 02: Toggle + Config + Distributable Summary

**`bsh on/off/status [--persist]` dispatcher with atomic key=value config persistence, built into a 636-line single-file distributable sourced by users**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-26T09:06:28Z
- **Completed:** 2026-02-26T09:08:36Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- `bsh on/off/status` work correctly in bash and zsh; `--persist` survives sessions via config file
- Atomic config write (`tmp.$$` then `mv`) with injection-safe key validation regex
- `make build` produces 636-line `better-shell.sh` with all components in correct concatenation order
- 14-test TAP suite covers toggle, persistence, config load, safety, and cleanup; all 28 total tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement config read/write and bsh toggle dispatcher** - `1278aa3` (feat)
2. **Task 2: Build distributable, create .gitignore, and write toggle/config tests** - `b0e8982` (feat)

**Plan metadata:** _(final docs commit follows)_

## Files Created/Modified

- `lib/config.sh` - _bsh_config_load (key=value reader, injection-safe, auto-called on source), _bsh_config_set (atomic write to tmp.PID then mv)
- `lib/toggle.sh` - bsh() dispatcher (on/off/status + --persist), _bsh_print_status (state/shell/audio/theme/version)
- `better-shell.sh` - Built 636-line distributable: vendor/bash-preexec.sh + all lib files in correct order
- `tests/test_toggle.sh` - 14-test TAP suite (7 toggle tests, 2 persistence tests, 5 config load/safety tests)
- `.gitignore` - Ignores editor/OS files (*.swp, *~, .DS_Store) and runtime config file
- `Makefile` - Fixed lib concatenation order (config.sh before env.sh); added test_toggle.sh to test target

## Decisions Made

- **config.sh before env.sh:** `_bsh_config_load` runs before `_bsh_is_interactive` gate, so a persisted `ssh_enabled=1` can override the default `_BSH_SSH_ENABLED=0` before the gate evaluates it.
- **Atomic write:** `_bsh_config_set` writes to `${config}.tmp.$$` then `mv`-s atomically — no partial-write corruption if the process is interrupted.
- **better-shell.sh in git:** Users who `git clone` the repo get a working plugin immediately; no need for `make` at install time.
- **_bsh_config_load auto-called:** Called at the bottom of config.sh so sourcing the file always loads persisted state; no separate init step needed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 1 hook infrastructure is complete: hook functions capture commands/exit codes/durations; `bsh` controls the plugin; persisted state survives sessions.
- Phase 2 (audio/visual feedback) can immediately read `_BSH_LAST_EXIT`, `_BSH_CMD_DURATION`, and `_BSH_LAST_CMD` from `_bsh_precmd`; set `_BSH_AUDIO_TOOL` for display in `bsh status`.
- Phase 3 (themes) can set `_BSH_THEME` for display in `bsh status`.
- Phase 4 (TOML triggers) can extend `_bsh_config_load`/`_bsh_config_set` or replace with TOML parser without changing the `bsh` public API.

---
*Phase: 01-hook-infrastructure*
*Completed: 2026-02-26*

## Self-Check: PASSED

All files verified present. All task commits verified in git history.

| Item | Status |
|------|--------|
| lib/config.sh | FOUND |
| lib/toggle.sh | FOUND |
| better-shell.sh | FOUND |
| tests/test_toggle.sh | FOUND |
| .gitignore | FOUND |
| .planning/phases/01-hook-infrastructure/01-02-SUMMARY.md | FOUND |
| Commit 1278aa3 (Task 1) | FOUND |
| Commit b0e8982 (Task 2) | FOUND |
