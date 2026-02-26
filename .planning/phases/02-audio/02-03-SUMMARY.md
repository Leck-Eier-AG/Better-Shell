---
phase: 02-audio
plan: 03
subsystem: audio
tags: [bash, zsh, audio, job-control, set+m, threshold, error-sounds, tap-tests]

# Dependency graph
requires:
  - phase: 02-audio
    provides: audio trigger logic (_bsh_audio_trigger), audio player (_bsh_play_sound), test suite

provides:
  - Error sounds now play for fast-failing commands (duration=0, exit != 0) by bypassing threshold
  - Job control "[N] done" messages suppressed via set +m in parent shell context
  - 30-test suite covering all three behavioural truths (error bypass, threshold still blocks success, blacklist blocks errors)

affects: [02-audio, UAT-retest, better-shell.sh distributable]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Event-type determination before gate checks: determine what happened (error/warning/success) before deciding whether to act on it"
    - "Parent-shell set +m pattern: disable monitor mode in parent before backgrounding subshell to suppress job completion messages"
    - "set +m / set -m sandwich: restore monitor mode immediately after disown so interactive session is unaffected"

key-files:
  created: []
  modified:
    - lib/audio.sh
    - lib/audio-player.sh
    - tests/test_audio.sh
    - better-shell.sh

key-decisions:
  - "Error events bypass the duration threshold; non-error events (success/warning) still apply threshold as before; blacklist applies to all events"
  - "set +m must run in the parent shell, not inside the backgrounded subshell — the parent is what prints job notifications"
  - "set -m restores monitor mode after disown so interactive users retain job control for their own commands"
  - "No automated test for job control fix — test harness is non-interactive; UAT re-test is the verification vehicle"

patterns-established:
  - "Determine event type first, then gate: prevents gates from masking important events (errors) meant to bypass them"
  - "set +m 2>/dev/null before ( ) &; set -m 2>/dev/null after disown — the canonical pattern for silent background audio"

requirements-completed: [AUD-01, AUD-02]

# Metrics
duration: 2min
completed: 2026-02-26
---

# Phase 02 Plan 03: UAT Gap Closure Summary

**Error sounds now fire for fast-failing commands (`false`, typos) and background audio playback is silent — two root-cause fixes restoring 2 of 3 UAT failures, 30 tests all pass.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-26T11:56:18Z
- **Completed:** 2026-02-26T11:58:38Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Fixed `_bsh_audio_trigger` decision flow: event type is now determined before the threshold gate, so error events (non-zero exit) bypass the duration threshold entirely; `false` and any fast-failing command will now play an error sound
- Fixed `_bsh_play_sound` job control leak: `set +m` moved from inside the backgrounded subshell (where it was a no-op) to the parent shell context before `( ) &`, with `set -m` after `disown $!` to restore monitor mode
- Test suite expanded to 30 tests: Test 17 updated to assert correct error-bypass behaviour; Tests 29 and 30 added to assert threshold still blocks successes and blacklist still blocks error sounds from interactive commands

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix error events bypassing threshold and update tests** - `ff95489` (fix)
2. **Task 2: Fix job control message leak and rebuild distributable** - `5ccb8b2` (fix)

## Files Created/Modified

- `/home/maxi/Documents/coding/Projects/Better-Shell/lib/audio.sh` - Reordered _bsh_audio_trigger: event-type determination moved before threshold gate; error events now bypass threshold, blacklist still applies
- `/home/maxi/Documents/coding/Projects/Better-Shell/lib/audio-player.sh` - `set +m` moved to parent shell context; `set -m` added after `disown $!`; updated function comment to document correct pattern
- `/home/maxi/Documents/coding/Projects/Better-Shell/tests/test_audio.sh` - Test 17 updated; Tests 29 and 30 added; `_BSH_PROJECT_ROOT`/`_BSH_DIR_SAVED` initialised at top of file so Phase F tests can reference bundled sounds
- `/home/maxi/Documents/coding/Projects/Better-Shell/better-shell.sh` - Rebuilt distributable incorporating both fixes

## Decisions Made

- Error events bypass the duration threshold; non-error events still apply threshold. This preserves the intended UX: trivial `ls` and `echo` commands stay silent, while `false` and failed `make build` always alert. Blacklist still applies to all event types so `vim` never generates error sounds even on a dirty exit.
- `set +m` must run in the parent shell. The original code placed it inside `( ) &` (the child), which has zero effect on the parent's job notification machinery. The fix is architecturally simple but requires understanding which shell context prints "[N] done" messages.
- No automated test for job control fix. `set +m` suppression can only be observed in a real interactive terminal — the test harness runs in non-interactive mode where monitor mode is already off. UAT re-test is the appropriate verification.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `_BSH_PROJECT_ROOT` and `_BSH_DIR_SAVED` used in Test 17 before they were assigned**
- **Found during:** Task 1 (updating test_audio.sh Test 17 to use bundled sounds)
- **Issue:** The plan specified Test 17 should verify error bypass by checking the resolved file path contains "error", which requires pointing `_BSH_DIR` at the project root. However, `_BSH_PROJECT_ROOT` and `_BSH_DIR_SAVED` were first assigned in Phase H (Test 23), causing them to be unset when Test 17 ran.
- **Fix:** Moved `_BSH_PROJECT_ROOT` initialisation to the setup section at the top of the test file (before Phase A); initialised `_BSH_DIR_SAVED` immediately after `_BSH_DIR` in setup. Removed redundant duplicate assignments from Test 23.
- **Files modified:** `tests/test_audio.sh`
- **Verification:** All 30 tests pass; Test 17 correctly resolves the bundled error sound
- **Committed in:** `ff95489` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug in test ordering)
**Impact on plan:** Required to make Test 17 work as designed. No scope creep.

## Issues Encountered

None — both fixes were diagnosed in the debug docs and applied directly without iteration.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both audio UAT gaps are closed (error sounds + job control silence). The third UAT gap (stderr detection / warning sounds) was pre-diagnosed as lower priority and blocked by the exec 2>(tee) fragility concern — no fix planned for this phase.
- UAT re-test can now proceed: source `better-shell.sh`, run `false` (error sound expected), run `echo hi` (silence expected), observe no `[N] done` messages after any audio playback.
- Phase 02 audio subsystem is functionally complete.

## Self-Check: PASSED

All key files found and all task commits verified:
- FOUND: lib/audio.sh
- FOUND: lib/audio-player.sh
- FOUND: tests/test_audio.sh
- FOUND: better-shell.sh
- FOUND: 02-03-SUMMARY.md
- FOUND: ff95489 (Task 1 commit)
- FOUND: 5ccb8b2 (Task 2 commit)

---
*Phase: 02-audio*
*Completed: 2026-02-26*
