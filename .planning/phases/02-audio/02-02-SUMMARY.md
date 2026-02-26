---
phase: 02-audio
plan: 02
subsystem: audio
tags: [wav, sox, python, sound-packs, stderr-detection, hot-reload, chiptune]

requires:
  - phase: 02-audio/02-01
    provides: audio engine (_bsh_play_sound, _bsh_audio_trigger, _bsh_resolve_sound)

provides:
  - 27 bundled WAV files across 3 thematic packs (meme, chill, retro)
  - CC0-licensed sounds with SOURCES.txt manifest
  - bsh sound-pack <name> subcommand for live pack switching
  - bsh volume <0-100> subcommand for volume control
  - Opt-in stderr detection triggering warning audio events
  - Config hot reload via mtime check on every precmd
  - User custom pack directory support (~/.config/better-shell/packs/)
  - Extended test suite: 28 audio tests covering all new features

affects: [03-visual, 04-config-rules]

tech-stack:
  added: [Python wave module (sound generation), scripts/gen_sounds.py]
  patterns:
    - Synthesized sounds avoid all licensing concerns (CC0 by construction)
    - Stderr detection is opt-in (exec redirect pattern is fragile by design)
    - Config hot reload via stat mtime avoids subshell cost on every command
    - User custom packs resolved at step 2 in search chain (after drop-in, before bundled)

key-files:
  created:
    - sounds/meme/error/{light,medium,heavy}.wav
    - sounds/meme/success/{light,medium,heavy}.wav
    - sounds/meme/warning/{light,medium,heavy}.wav
    - sounds/chill/error/{light,medium,heavy}.wav
    - sounds/chill/success/{light,medium,heavy}.wav
    - sounds/chill/warning/{light,medium,heavy}.wav
    - sounds/retro/error/{light,medium,heavy}.wav
    - sounds/retro/success/{light,medium,heavy}.wav
    - sounds/retro/warning/{light,medium,heavy}.wav
    - sounds/SOURCES.txt
    - scripts/gen_sounds.py
  modified:
    - lib/audio.sh
    - lib/hooks.sh
    - lib/toggle.sh
    - lib/config.sh
    - tests/test_audio.sh

key-decisions:
  - "Python wave module used instead of sox — sox unavailable on system, Python3 always present and wave/math/struct generate valid WAV with no external deps"
  - "Stderr detection defaults to OFF (_BSH_STDERR_DETECT=0) — exec 2>(tee) pattern adds background process per command and is fragile in some terminal emulators"
  - "Config hot reload uses stat mtime comparison — avoids re-sourcing cost; check happens once per precmd, only reloads on actual change"
  - "User custom packs resolved at step 2 in _bsh_resolve_sound — after drop-in override but before bundled pack, giving users full pack replacement without touching bundled sounds"

patterns-established:
  - "Sound path: user-dropin > user-custom-pack > bundled-pack (layered override)"
  - "Opt-in feature guard: check _BSH_STDERR_DETECT early and skip setup when off"
  - "fd 9 used as stderr save fd (fixed, bash 3.x compatible)"

requirements-completed: [AUD-03, AUD-04, AUD-09, AUD-10]

duration: 5min
completed: 2026-02-26
---

# Phase 02 Plan 02: Sound Packs and Audio Subsystem Completion Summary

**27 synthesized CC0 WAV files across meme/chill/retro packs, plus pack switching, volume control, opt-in stderr-warning detection, and config hot reload**

## Performance

- **Duration:** 5 min
- **Started:** 2026-02-26T11:21:20Z
- **Completed:** 2026-02-26T11:25:49Z
- **Tasks:** 2 of 3 (Task 3 is checkpoint:human-verify — awaiting user)
- **Files modified:** 16 (11 created, 5 modified)

## Accomplishments

- Generated 27 WAV files (3 packs x 3 categories x 3 intensities) using Python wave module — no external dependencies, CC0 by construction
- Implemented opt-in stderr detection: `_BSH_STDERR_DETECT=1` redirects stderr through tee; `_BSH_LAST_STDERR` drives warning audio category
- Added `bsh sound-pack` and `bsh volume` subcommands with config persistence and live variable update
- Added `_bsh_audio_config_check` for mtime-based hot reload: config changes take effect on next command without re-sourcing
- Extended user custom pack support: `~/.config/better-shell/packs/<name>/` resolved at step 2 in sound search chain
- Brought audio test suite to 28 tests, all passing alongside full `make test` (56 tests total)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create bundled sound packs and source manifest** - `a9097a4` (feat)
2. **Task 2: Implement stderr detection, pack switching, hot reload, and extend tests** - `52c2af0` (feat)

## Files Created/Modified

- `sounds/meme/error/{light,medium,heavy}.wav` - Meme pack error sounds (descending freq sweeps)
- `sounds/meme/success/{light,medium,heavy}.wav` - Meme pack success sounds (ascending fanfares)
- `sounds/meme/warning/{light,medium,heavy}.wav` - Meme pack warning sounds (wobble/alarm tones)
- `sounds/chill/error/{light,medium,heavy}.wav` - Chill pack error sounds (low-freq sines, exponential decay)
- `sounds/chill/success/{light,medium,heavy}.wav` - Chill pack success sounds (bell-like chimes, harmony chord)
- `sounds/chill/warning/{light,medium,heavy}.wav` - Chill pack warning sounds (soft pings, minor chord)
- `sounds/retro/error/{light,medium,heavy}.wav` - Retro pack error sounds (square wave descending)
- `sounds/retro/success/{light,medium,heavy}.wav` - Retro pack success sounds (coin blip, level-up, victory)
- `sounds/retro/warning/{light,medium,heavy}.wav` - Retro pack warning sounds (triangle pulse, alarm sequence)
- `sounds/SOURCES.txt` - CC0 licensing and generation documentation
- `scripts/gen_sounds.py` - Python sound generator (reproducible, included in repo)
- `lib/audio.sh` - Added _BSH_STDERR_DETECT default, user pack resolution, _bsh_audio_config_check
- `lib/hooks.sh` - Added opt-in stderr capture in _bsh_preexec, detection cleanup in _bsh_precmd
- `lib/toggle.sh` - Added sound-pack and volume subcommands, updated status output
- `lib/config.sh` - Added stderr_detect key mapping
- `tests/test_audio.sh` - 8 new tests (21-28) for all new features

## Decisions Made

- **Python wave instead of sox:** sox not installed on the target system. Python3's `wave`, `math`, and `struct` stdlib modules generate valid WAV files with no external deps. The generator is included in `scripts/gen_sounds.py` for reproducibility.
- **Stderr detection defaults OFF:** The `exec 2>(tee ...)` pattern spawns a background process per command. This adds latency, can cause stray `[1]+ Done` messages, and behaves differently across terminal emulators. Opt-in via `_BSH_STDERR_DETECT=1` respects users who don't need warning sounds.
- **Config hot reload via mtime:** Using `stat` mtime is the cheapest way to detect file changes without a subshell diff. `_BSH_CONFIG_MTIME` is cached; a mismatch triggers `_bsh_config_load`. This runs once per precmd cycle.
- **User custom pack at search step 2:** Placing user custom packs between the drop-in override and bundled pack allows users to create full alternative packs without conflicting with per-sound drop-ins.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test 28 mock function captured event via subshell variable**

- **Found during:** Task 2 (extending test suite)
- **Issue:** Initial test 28 tried to capture the `event` argument from a mocked `_bsh_resolve_sound` via a global variable, but the mock is called inside `$()` (command substitution subshell) — variable assignments in subshells don't propagate to the parent
- **Fix:** Restructured test 28 to point `_BSH_DIR` at the real project root so actual bundled sounds are resolved; then verified the resolved file path contains "warning" (the directory component) instead of trying to capture the event argument
- **Files modified:** tests/test_audio.sh
- **Verification:** Test 28 passes: `PLAY_FILE` contains "warning" when `_BSH_LAST_STDERR=1` and `_BSH_LAST_EXIT=0`
- **Committed in:** 52c2af0 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in test implementation)
**Impact on plan:** Test correctly validates the feature. No scope creep.

## Issues Encountered

- sox not available on Manjaro system — plan specified Python fallback, used it without deviation from intent

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Audio subsystem complete end-to-end: engine (02-01) + packs + controls (02-02)
- Task 3 (checkpoint:human-verify) awaits user confirmation that audio plays correctly in a live shell
- After checkpoint passes, plan 02-02 is fully complete and phase 02-audio moves to plan 03
- Phase 03 (visual feedback) can reference audio patterns: hook integration, threshold/blacklist/whitelist system

---
*Phase: 02-audio*
*Completed: 2026-02-26*
