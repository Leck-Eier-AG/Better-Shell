---
phase: 02-audio
plan: 01
subsystem: audio
tags: [shell, bash, zsh, audio, pw-play, paplay, afplay, aplay, TAP]

# Dependency graph
requires:
  - phase: 01-hook-infrastructure
    provides: "_bsh_precmd hook with _BSH_LAST_EXIT, _BSH_CMD_DURATION, _BSH_LAST_CMD variables"
provides:
  - "lib/audio-player.sh: player detection, volume normalisation, non-blocking async playback"
  - "lib/audio.sh: trigger logic with threshold/blacklist/whitelist/intensity/sound-resolution"
  - "lib/hooks.sh: _bsh_audio_trigger integrated into _bsh_precmd"
  - "lib/config.sh: audio_threshold, sound_pack, volume, scaling_method config keys"
  - "tests/test_audio.sh: 20 TAP-style tests for the audio subsystem"
affects:
  - 02-audio (plans 02+)
  - 04-config-cli (reads _BSH_VOLUME, _BSH_SOUND_PACK, _BSH_AUDIO_THRESHOLD)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Player detection at source time via command -v probe loop"
    - "Non-blocking audio via subshell with set +m, & disown"
    - "ERE blacklist/whitelist matching via [[ =~ $unquoted_pattern ]]"
    - "Sound file resolution: user drop-in override before bundled pack"
    - "Intensity bucketing: light < 5s, medium 5-30s, heavy > 30s"

key-files:
  created:
    - lib/audio-player.sh
    - lib/audio.sh
    - tests/test_audio.sh
  modified:
    - lib/hooks.sh
    - lib/config.sh
    - Makefile
    - tests/test_hooks.sh

key-decisions:
  - "Use SECONDS integer threshold of 1s (closest to 500ms user intent given integer resolution)"
  - "Probe player order: pw-play > paplay > afplay > aplay (PipeWire first on modern Linux)"
  - "Whitelist overrides both threshold and blacklist (explicit user intent wins)"
  - "ERE patterns in arrays; do NOT quote in [[ =~ ]] (quoting disables regex in bash/zsh)"
  - "Stub _bsh_audio_trigger in test_hooks.sh to prevent command-not-found noise"

patterns-established:
  - "Audio no-op pattern: empty _BSH_AUDIO_TOOL = completely silent, no errors"
  - "Volume normalisation: float 0.00-1.00 for pw-play/afplay, integer 0-65536 for paplay"
  - "Test mock pattern: redefine function (_bsh_play_sound) to capture call data"

requirements-completed: [AUD-01, AUD-02, AUD-05, AUD-06, AUD-07, AUD-08]

# Metrics
duration: 2min
completed: 2026-02-26
---

# Phase 2 Plan 01: Audio Engine and Trigger Logic Summary

**Cross-platform audio playback engine with threshold/blacklist/whitelist trigger logic wired into precmd hook, detecting pw-play/paplay/afplay/aplay at load time with async non-blocking dispatch**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-26T11:15:26Z
- **Completed:** 2026-02-26T11:17:50Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Player detection at source time storing result in `_BSH_AUDIO_TOOL`; empty = silent no-op on systems without audio
- Non-blocking async playback via `subshell + set +m + & + disown` preventing job-control noise at prompt
- Full trigger decision chain: whitelist override > threshold > blacklist > event type > intensity > sound resolution
- 20 TAP-style tests passing; `make test` succeeds (48 total across all three test files)

## Task Commits

Each task was committed atomically:

1. **Task 1: Audio player detection and non-blocking playback engine** - `d84efd2` (feat)
2. **Task 2: Audio trigger logic, precmd integration, build update** - `c931b31` (feat)
3. **Task 3: TAP-style audio subsystem tests** - `f31d485` (test)

**Plan metadata:** (see below — docs commit after SUMMARY creation)

## Files Created/Modified

- `lib/audio-player.sh` - Player detection, volume normalisation helpers, async _bsh_play_sound
- `lib/audio.sh` - _bsh_audio_trigger, blacklist/whitelist arrays, _bsh_get_intensity, _bsh_resolve_sound
- `lib/hooks.sh` - Added _bsh_audio_trigger call in _bsh_precmd, removed Phase 2+ placeholder comment
- `lib/config.sh` - Extended case statement with audio_threshold, sound_pack, volume, scaling_method
- `Makefile` - Added audio-player.sh and audio.sh to LIB; added test_audio.sh to test target
- `tests/test_audio.sh` - 20 TAP tests: existence, detection, volume, blacklist/whitelist, intensity, dispatch, resolution
- `tests/test_hooks.sh` - Added _bsh_audio_trigger stub to prevent command-not-found noise

## Decisions Made

- **SECONDS integer threshold:** SECONDS in bash/zsh is integer; 1s is the closest achievable threshold to the 500ms user intent (duration=0 is skipped, 1+ plays).
- **Player probe order:** pw-play > paplay > afplay > aplay prioritises PipeWire on modern Linux systems, then PulseAudio, then macOS, then ALSA.
- **Whitelist overrides all:** Explicit whitelist match bypasses both threshold and blacklist — user intent should always win.
- **Unquoted ERE pattern in [[ =~ ]]:** Quoting the pattern disables regex matching in bash/zsh; patterns stored in array and used unquoted in test expression.
- **Test stub for hooks test isolation:** test_hooks.sh sources hooks.sh without audio.sh; added no-op stub to avoid stderr noise while preserving test file isolation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Suppressed _bsh_audio_trigger command-not-found in test_hooks.sh**
- **Found during:** Task 3 (running make test after test_audio.sh creation)
- **Issue:** test_hooks.sh sources hooks.sh but not audio.sh; after Task 2 added the audio trigger call to _bsh_precmd, calling _bsh_precmd in test_hooks.sh produced "command not found" stderr noise on tests 10, 11, 13 (tests still passed but output was noisy)
- **Fix:** Added `_bsh_audio_trigger() { :; }` stub after sourcing hooks.sh in test_hooks.sh
- **Files modified:** tests/test_hooks.sh
- **Verification:** make test runs 48/48 tests with no stderr noise
- **Committed in:** f31d485 (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Necessary for clean test output; no scope creep.

## Issues Encountered

None — plan executed as designed with one minor test-noise fix.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Audio engine is fully functional; commands will trigger _bsh_audio_trigger on every precmd call
- Sound files need to be bundled (AUD-03 blocker: CC0 licensing source unresolved) — trigger will silently no-op until sounds exist in ${_BSH_DIR}/sounds/
- Phase 2 Plan 02 can proceed (likely sound pack bundling or CLI config for audio settings)

---
*Phase: 02-audio*
*Completed: 2026-02-26*
