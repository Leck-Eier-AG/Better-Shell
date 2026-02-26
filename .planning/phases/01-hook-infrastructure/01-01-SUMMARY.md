---
phase: 01-hook-infrastructure
plan: 01
subsystem: infra
tags: [bash, zsh, bash-preexec, hooks, preexec, precmd, shell-plugin]

# Dependency graph
requires: []
provides:
  - lib/header.sh: idempotency guard, _BSH_VERSION, _BSH_DIR, _BSH_ENABLED, _BSH_SSH_ENABLED
  - lib/env.sh: _bsh_is_interactive() with interactive/TTY/SSH/CI detection + gate
  - lib/compat.sh: bash/zsh shell detection, bash-preexec sourcing, add-zsh-hook setup
  - lib/hooks.sh: _bsh_preexec (start time + cmd recording), _bsh_precmd (exit code + duration)
  - vendor/bash-preexec.sh: bundled v0.6.0 for bash preexec hook support
  - Makefile: build/clean/test targets; concatenates vendor + lib into better-shell.sh
  - tests/test_hooks.sh: 14 TAP-style integration tests for hook infrastructure
affects:
  - 01-hook-infrastructure/01-02 (toggle + config layer builds on _BSH_ENABLED, _BSH_DIR, hook functions)
  - All future phases depend on _bsh_preexec/_bsh_precmd/_BSH_LAST_EXIT/_BSH_CMD_DURATION

# Tech tracking
tech-stack:
  added:
    - bash-preexec v0.6.0 (vendored)
    - GNU Make (build system)
  patterns:
    - idempotency guard via _BSH_LOADED variable
    - multi-check interactive gate (_bsh_is_interactive)
    - hook array append (preexec_functions+=, add-zsh-hook) — never clobbers existing hooks
    - exit code capture as first line of precmd
    - _BSH_ prefix for globals, _bsh_ prefix for functions

key-files:
  created:
    - lib/header.sh
    - lib/env.sh
    - lib/compat.sh
    - lib/hooks.sh
    - vendor/bash-preexec.sh
    - Makefile
    - tests/test_hooks.sh
  modified: []

key-decisions:
  - "Use bash-preexec v0.6.0 (bundled in vendor/) for bash preexec hooks — avoids DEBUG trap edge cases"
  - "Hook registration via array append (preexec_functions+=, add-zsh-hook) to never clobber existing hooks"
  - "Exit code captured as first line of _bsh_precmd before any other operation"
  - "Interactive gate (_bsh_is_interactive) blocks SSH by default; CI environments always blocked"
  - "Concatenation build via Makefile: vendor + lib files -> single better-shell.sh for users to source"
  - "emulate -L zsh guard in _bsh_preexec to handle unusual zsh framework option states"

patterns-established:
  - "Idempotency guard: [[ -n \"${_BSH_LOADED:-}\" ]] && return 0 at top of header.sh"
  - "Interactive detection: ordered checks ($-, TTY, SSH, CI) with early returns"
  - "Hook isolation: all internal variables _BSH_* (globals) and _bsh_* (functions) prefixed"
  - "No output from hook functions: hooks must never write to stdout or stderr"

requirements-completed: [HOOK-01, HOOK-02, HOOK-03]

# Metrics
duration: 3min
completed: 2026-02-26
---

# Phase 1 Plan 01: Hook Infrastructure Summary

**bash-preexec v0.6.0 bundled as vendor dependency with zsh add-zsh-hook; preexec/precmd hooks capture command string, exit code, and duration with no stdout output; 14-test TAP suite validates all behavior**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-26T09:00:12Z
- **Completed:** 2026-02-26T09:03:56Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Core lib files (header, env, compat, hooks) implement the full hook infrastructure for bash and zsh
- Environment detection correctly blocks non-interactive, CI, and SSH-by-default contexts
- Hook functions (_bsh_preexec, _bsh_precmd) record command string, exit code, and duration with zero output
- 14-test TAP suite covers idempotency, environment detection (3 cases), shell detection, hook existence, exit code capture, duration tracking, and enabled guard

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold project and create environment detection + shell compat layer** - `be45878` (feat)
2. **Task 2: Implement preexec/precmd hooks and hook registration** - `ef1562d` (feat)
3. **Task 3: Create integration test script for hook behavior** - `c797f2d` (feat)

**Plan metadata:** _(final docs commit follows)_

## Files Created/Modified

- `lib/header.sh` - Idempotency guard (_BSH_LOADED), version, _BSH_DIR, _BSH_ENABLED, _BSH_SSH_ENABLED
- `lib/env.sh` - _bsh_is_interactive() with interactive/$-/TTY/SSH/CI checks; gate at end
- `lib/compat.sh` - Shell detection (_BSH_SHELL), bash-preexec sourcing for bash, autoload add-zsh-hook for zsh
- `lib/hooks.sh` - _bsh_preexec (start time + cmd), _bsh_precmd (exit code first, duration), hook registration
- `vendor/bash-preexec.sh` - Bundled bash-preexec v0.6.0 with pinned URL comment
- `Makefile` - build (cat vendor + lib files), clean, test targets; wildcard for future Plan 02 files
- `tests/test_hooks.sh` - 14 TAP-style integration tests; all pass via `make test`

## Decisions Made

- **bash-preexec bundled at v0.6.0:** Avoids DEBUG trap pitfalls (fires in subshells, pipelines). bash-preexec's deferred install mechanism handles PROMPT_COMMAND ordering. Concatenated into better-shell.sh at build time.
- **Hook registration via arrays:** `preexec_functions+=(_bsh_preexec)` and `add-zsh-hook preexec _bsh_preexec` never clobber existing hooks from other shell plugins.
- **Exit code first in precmd:** `local _bsh_exit=$?` is the absolute first line — any prior operation resets $?.
- **SSH blocked by default:** SSH_TTY and SSH_CLIENT checks require `_BSH_SSH_ENABLED=1` to load plugin in SSH sessions.
- **Wildcard in Makefile LIB:** `$(wildcard $(LIB))` means toggle.sh and config.sh (Plan 02) can be listed without breaking current build.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test script used `set -euo pipefail` which caused `false; _bsh_precmd` test to abort**
- **Found during:** Task 3 (integration test script)
- **Issue:** `set -e` exits the script on any non-zero return code; the test for exit code 1 (`false` followed by `_bsh_precmd`) caused the script to abort after `false`, never running `_bsh_precmd`. Additionally, bash-preexec's PROMPT_COMMAND install caused duplicate output on the first test run.
- **Fix:** Removed `set -euo pipefail`; split `false; _bsh_precmd` into two separate lines (separate statements) to ensure `_bsh_precmd` captures $? correctly; sourced vendor/bash-preexec.sh explicitly before compat.sh in Phase B to control initialization order.
- **Files modified:** tests/test_hooks.sh
- **Verification:** All 14 tests pass via `make test`
- **Committed in:** c797f2d (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Necessary correctness fix in the test infrastructure. No scope creep.

## Issues Encountered

- bash-preexec's deferred PROMPT_COMMAND install caused the test script header to be printed twice on first run. Fixed by explicit sourcing order (vendor first, then compat.sh which skips re-source if already loaded).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Hook infrastructure complete. _bsh_preexec, _bsh_precmd, _BSH_LAST_EXIT, _BSH_CMD_DURATION, _BSH_LAST_CMD all set correctly on each command.
- Plan 02 (toggle + config layer) can build on _BSH_ENABLED, _BSH_DIR, and the hook functions immediately.
- `make build` will include toggle.sh and config.sh automatically once they exist (wildcard handles it).

---
*Phase: 01-hook-infrastructure*
*Completed: 2026-02-26*

## Self-Check: PASSED

All files verified present. All task commits verified in git history.

| Item | Status |
|------|--------|
| lib/header.sh | FOUND |
| lib/env.sh | FOUND |
| lib/compat.sh | FOUND |
| lib/hooks.sh | FOUND |
| vendor/bash-preexec.sh | FOUND |
| Makefile | FOUND |
| tests/test_hooks.sh | FOUND |
| .planning/phases/01-hook-infrastructure/01-01-SUMMARY.md | FOUND |
| Commit be45878 (Task 1) | FOUND |
| Commit ef1562d (Task 2) | FOUND |
| Commit c797f2d (Task 3) | FOUND |
