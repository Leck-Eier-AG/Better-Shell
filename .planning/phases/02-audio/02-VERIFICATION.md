---
phase: 02-audio
verified: 2026-02-26T13:00:00Z
status: human_needed
score: 12/12 automated must-haves verified
human_verification:
  - test: "Source better-shell.sh in an interactive terminal. Run `false`. Confirm an error sound plays immediately with no delay."
    expected: "Error sound plays even though `false` completes in under 1 second (threshold bypass verified in code)."
    why_human: "Audio playback cannot be observed programmatically; requires a real interactive terminal with audio output."
  - test: "Run `echo hi`. Confirm no sound plays."
    expected: "Silence — command duration is 0s which is below the 1s threshold and exit code is 0."
    why_human: "Absence of sound cannot be verified programmatically."
  - test: "Run `sleep 2` then check that the prompt returns immediately AND no '[N] done ...' messages appear in the terminal after the sound finishes."
    expected: "Prompt returns at once; audio plays in the background; terminal stays clean."
    why_human: "Job-control suppression (set +m in parent) can only be observed in a real interactive terminal — the test harness runs non-interactive where monitor mode is already off."
  - test: "Run `bsh sound-pack retro` then `false`. Confirm the error sound has a different (chiptune/square-wave) character from the default meme pack."
    expected: "Audibly different error sound plays after pack switch."
    why_human: "Sound character differences require human perception; file existence is already verified programmatically."
  - test: "Run `bsh volume 20` then `sleep 2`. Then `bsh volume 80` then `sleep 2`. Confirm audible volume difference."
    expected: "Noticeably quieter at 20, louder at 80."
    why_human: "Volume level perception requires human judgment."
---

# Phase 02: Audio Verification Report

**Phase Goal:** Users hear immediate, non-blocking audio feedback on command error and success, with sensible defaults that prevent noise on trivial commands
**Verified:** 2026-02-26T13:00:00Z
**Status:** human_needed — all automated checks pass; 5 items need interactive terminal testing
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running a failing command triggers `_bsh_audio_trigger` with event=error | VERIFIED | `lib/audio.sh:182` — `_BSH_LAST_EXIT -ne 0` sets `event="error"` before threshold; Test 17 and Test 19 confirm dispatch |
| 2 | Running a successful command triggers `_bsh_audio_trigger` with event=success | VERIFIED | `lib/audio.sh:187` — else branch sets `event="success"`; Test 19 inverts to confirm success path |
| 3 | Commands under the time threshold (1s, closest to 500ms) produce no audio trigger for success events | VERIFIED | `lib/audio.sh:199` — threshold check for non-error events only; Test 29 passes: duration=0, exit=0 → no play |
| 4 | Blacklisted commands (vim, man, ssh, etc.) produce no audio trigger | VERIFIED | `lib/audio.sh:36-41` — 17 patterns; Test 9, 10, 11, 12, 18, 30 all pass |
| 5 | Whitelisted commands override both threshold and blacklist | VERIFIED | `lib/audio.sh:191` — `_bsh_in_whitelist` checked before gate; Test 13 confirms empty whitelist; code path verified |
| 6 | Audio playback is non-blocking | VERIFIED | `lib/audio-player.sh:111` — `( ... ) &` with `disown $!`; next prompt not blocked |
| 7 | Job control messages are suppressed | VERIFIED (code) | `lib/audio-player.sh:95` — `set +m 2>/dev/null` in parent before `( ) &`; `set -m` after disown; needs human confirm |
| 8 | Plugin detects available audio player at load time | VERIFIED | `lib/audio-player.sh:56-65` — probe loop at line 123 runs at source time; Test 4 confirms `_BSH_AUDIO_TOOL=pw-play` |
| 9 | Systems with no audio player silently no-op | VERIFIED | `lib/audio-player.sh:87` — guard returns 0 when `_BSH_AUDIO_TOOL` empty; Test 4 handles empty case |
| 10 | 3 bundled sound packs with 27 total WAV files (meme, chill, retro) | VERIFIED | `find sounds/ -name "*.wav"` = 27 files across all 3 packs x 3 categories x 3 intensities |
| 11 | User can switch active sound pack via `bsh sound-pack <name>` | VERIFIED | `lib/toggle.sh:51-72` — subcommand present; `_bsh_config_set` persists; Test 22 passes |
| 12 | User can drop custom sound files into `~/.config/better-shell/sounds/` | VERIFIED | `lib/audio.sh:113` — user drop-in is step 1 in resolution chain; `_bsh_resolve_sound` checks this path first |

**Score:** 12/12 automated truths verified

---

## Required Artifacts

### Plan 02-01 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/audio-player.sh` | Player detection, volume normalisation, non-blocking playback | VERIFIED | 124 lines; exports `_bsh_detect_audio_player`, `_bsh_play_sound`, `_bsh_vol_afplay`, `_bsh_vol_pw`, `_bsh_vol_paplay` |
| `lib/audio.sh` | Trigger logic, blacklist/whitelist, intensity, sound resolution | VERIFIED | 215 lines; exports `_bsh_audio_trigger`, `_bsh_is_blacklisted`, `_bsh_in_whitelist`, `_bsh_get_intensity`, `_bsh_resolve_sound`, `_bsh_audio_config_check` |
| `tests/test_audio.sh` | TAP-style integration tests | VERIFIED | 463 lines (well above 80-line minimum); 30 tests, all pass |

### Plan 02-02 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `sounds/meme/error/light.wav` | Default meme pack light error sound | VERIFIED | File exists; valid WAV |
| `sounds/SOURCES.txt` | License and source documentation for all bundled sounds | VERIFIED | CC0 1.0 declared; Python wave module generation documented |
| `lib/toggle.sh` | `bsh sound-pack` subcommand | VERIFIED | Lines 51-72 implement `sound-pack`; line 73-81 implement `volume` |

### Plan 02-03 Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/audio.sh` | Event-type determination BEFORE threshold gate | VERIFIED | Lines 181-188 determine event; threshold check at line 199 is inside `else` (non-error only) |
| `lib/audio-player.sh` | `set +m` in parent shell context before backgrounding | VERIFIED | Line 95: `set +m 2>/dev/null` in parent; line 114: `set -m 2>/dev/null` after disown |
| `tests/test_audio.sh` | Tests for error-bypasses-threshold and threshold-blocks-success | VERIFIED | Test 17 (error bypasses threshold), Test 29 (threshold blocks success), Test 30 (blacklist blocks errors) all pass |
| `better-shell.sh` | Rebuilt distributable with both fixes | VERIFIED | `grep -c "_bsh_play_sound"` = 6 occurrences; syntax check passes |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `lib/hooks.sh (_bsh_precmd)` | `lib/audio.sh (_bsh_audio_trigger)` | Call at end of precmd | WIRED | `lib/hooks.sh:61` — `_bsh_audio_trigger` called after duration calc and stderr cleanup |
| `lib/audio.sh (_bsh_audio_trigger)` | `lib/audio-player.sh (_bsh_play_sound)` | Call with resolved sound file | WIRED | `lib/audio.sh:213` — `_bsh_play_sound "$sound_file"` |
| `lib/audio-player.sh` | system audio player | `_BSH_AUDIO_TOOL` detected at load time | WIRED | `lib/audio-player.sh:123` — `_bsh_detect_audio_player` called at source time; Test 4 confirms `pw-play` detected |
| `lib/audio.sh (_bsh_resolve_sound)` | `sounds/` directory | File path glob with `_BSH_DIR` and `_BSH_SOUND_PACK` | WIRED | `lib/audio.sh:113-116` — 3-step search chain; Test 23 resolves real bundled file |
| `lib/hooks.sh (_bsh_preexec)` | `lib/audio.sh (_bsh_audio_trigger)` | stderr capture setup, `_BSH_LAST_STDERR` check | WIRED | `lib/hooks.sh:27-32` (capture), `lib/hooks.sh:54-58` (cleanup); `_BSH_LAST_STDERR` read by trigger at `audio.sh:184` |
| `lib/toggle.sh (bsh)` | `_BSH_SOUND_PACK` variable | `bsh sound-pack` sets variable and persists via `_bsh_config_set` | WIRED | `lib/toggle.sh:68-69` — `_BSH_SOUND_PACK="$2"` + `_bsh_config_set sound_pack "$2"` |
| `Makefile` | `lib/audio-player.sh`, `lib/audio.sh` | LIB list for build concatenation | WIRED | `Makefile:14` — both files present in LIB after `lib/hooks.sh` |
| `Makefile` | `tests/test_audio.sh` | test target command | WIRED | `Makefile:42` — `bash tests/test_audio.sh` in test recipe |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUD-01 | 02-01, 02-03 | Play configurable sound on non-zero exit code (error) | SATISFIED | `_bsh_audio_trigger` event determination + `_bsh_resolve_sound` + `_bsh_play_sound`; error bypasses threshold (02-03 fix); Tests 17, 18, 19, 30 |
| AUD-02 | 02-01, 02-03 | Play configurable sound on success (zero exit code) | SATISFIED | Success event path in `_bsh_audio_trigger`; threshold correctly blocks trivial commands; Test 29 |
| AUD-03 | 02-02 | Ship default bundled sound files | SATISFIED | 27 WAV files across meme/chill/retro packs; `sounds/SOURCES.txt` present |
| AUD-04 | 02-02 | Allow user-provided custom sound files | SATISFIED | Step 1 in `_bsh_resolve_sound` checks `~/.config/better-shell/sounds/<event>/`; step 2 checks user custom packs |
| AUD-05 | 02-01 | Cross-platform audio playback detection | SATISFIED | `_bsh_detect_audio_player` probes pw-play, paplay, afplay, aplay in preference order |
| AUD-06 | 02-01 | All audio playback is non-blocking | SATISFIED | `( ... ) &` with `disown $!` in `_bsh_play_sound`; prompt not blocked |
| AUD-07 | 02-01 | Configurable time threshold | SATISFIED | `_BSH_AUDIO_THRESHOLD` variable (default 1s); applied in `_bsh_audio_trigger` for non-error events; persisted via `_bsh_config_set` |
| AUD-08 | 02-01 | Command blacklist | SATISFIED | `_BSH_BLACKLIST_PATTERNS` array with 17 ERE patterns; `_bsh_is_blacklisted` checked for all events including errors |
| AUD-09 | 02-02 | Sound packs with one-command swap | SATISFIED | `bsh sound-pack <name>` in `lib/toggle.sh`; `_bsh_config_set sound_pack` persists; Test 22 |
| AUD-10 | 02-02 | Detect and trigger on stderr output | SATISFIED (opt-in) | `_BSH_STDERR_DETECT=1` enables capture via `exec 2>(tee ...)`; `_BSH_LAST_STDERR` drives warning event; Test 28. **Note:** defaults to OFF by design — fragile across terminal emulators |

**All 10 audio requirements: SATISFIED**

---

## Anti-Patterns Found

No anti-patterns detected in any of the modified files:
- No TODO/FIXME/HACK/PLACEHOLDER comments in `lib/audio.sh`, `lib/audio-player.sh`, `lib/hooks.sh`, `lib/toggle.sh`, or `lib/config.sh`
- No stub return values (`return null`, empty arrays with no logic)
- No console.log-only implementations
- No placeholders in `tests/test_audio.sh`

---

## Test Suite Results

**`make test` output — all 58 tests pass:**

| Suite | Tests | Passed | Failed |
|-------|-------|--------|--------|
| `tests/test_hooks.sh` | 14 | 14 | 0 |
| `tests/test_toggle.sh` | 14 | 14 | 0 |
| `tests/test_audio.sh` | 30 | 30 | 0 |
| **Total** | **58** | **58** | **0** |

---

## Human Verification Required

The following items passed all automated checks but require an interactive terminal to confirm real-world behavior. These correspond to the 3 UAT gaps that were diagnosed and closed in Plan 02-03, plus standard audio quality checks.

### 1. Error sound plays for fast-failing commands

**Test:** Source `better-shell.sh` in an interactive terminal. Run `false`. Listen for an error sound.
**Expected:** An error sound plays immediately (within ~0.5s) with no visible delay at the prompt. The sound should be from the meme/error/light.wav file (short descending tone).
**Why human:** Audio playback cannot be verified programmatically. This was a UAT-confirmed failure (test 3 in UAT.md) that was fixed in Plan 02-03 by reordering event determination before the threshold gate.

### 2. No sound on trivial success commands

**Test:** Run `echo hi`. Confirm silence.
**Expected:** No sound plays. The command completes in 0s which is below the 1s threshold.
**Why human:** Absence of audio cannot be detected programmatically.

### 3. Background audio is completely silent (no job control messages)

**Test:** Run `sleep 2` and wait for the sound to play through. Observe the terminal carefully after the prompt returns.
**Expected:** Prompt returns immediately; sound plays in background; NO `[N] done ...` messages appear in the terminal at any point.
**Why human:** The `set +m` fix (moving from inside the subshell to the parent shell) can only be validated in a real interactive terminal. The test harness is non-interactive where monitor mode is already off, so automated tests cannot detect this regression path. This was UAT test 7 failure, fixed in Plan 02-03.

### 4. Sound pack switching produces audibly different sounds

**Test:** Run `bsh sound-pack retro`. Then run `false`. Then run `bsh sound-pack chill` and `false` again.
**Expected:** Each pack produces a distinctly different error sound character: meme=dramatic descending sweep, retro=square-wave chiptune, chill=soft low tone.
**Why human:** Sound character differences require human auditory perception.

### 5. Volume control is audible

**Test:** Run `bsh volume 20` then `sleep 2`. Then `bsh volume 80` then `sleep 2`.
**Expected:** Noticeably quieter at volume 20, louder at volume 80.
**Why human:** Volume perception requires human judgment; the programmatic change to `_BSH_VOLUME` is verified (Test 25) but the audio output level is not.

---

## Commit Verification

All commits documented in SUMMARY files confirmed present in git log:

| Commit | Plan | Description |
|--------|------|-------------|
| `d84efd2` | 02-01 Task 1 | Audio player detection and playback engine |
| `c931b31` | 02-01 Task 2 | Audio trigger logic, precmd integration, build update |
| `f31d485` | 02-01 Task 3 | TAP-style audio subsystem tests (20 tests) |
| `a9097a4` | 02-02 Task 1 | Bundle 3 sound packs with 27 CC0-licensed WAV files |
| `52c2af0` | 02-02 Task 2 | Stderr detection, pack switching, volume, hot reload, 8 new tests |
| `ff95489` | 02-03 Task 1 | Reorder audio trigger so error events bypass duration threshold |
| `5ccb8b2` | 02-03 Task 2 | Move set +m to parent shell to suppress job control messages |

---

## Summary

Phase 02 goal is **achieved at the code level**. Every automated must-have passes:

- The audio engine detects players, plays sounds non-blocking and asynchronously, and handles no-audio systems silently.
- The trigger logic correctly determines event type BEFORE applying the threshold gate (the post-UAT fix), ensuring fast-failing commands like `false` produce error sounds.
- All 10 audio requirements (AUD-01 through AUD-10) are implemented and wired end-to-end.
- 27 bundled CC0-licensed WAV files exist across 3 packs. `bsh sound-pack` and `bsh volume` commands work and persist to config.
- The `set +m` job control fix is in the correct location (parent shell context).
- All 30 audio tests pass; full `make test` passes 58/58 tests.

The 5 human verification items above are confirmations that the audio subsystem works correctly in a live interactive terminal session — the final gate before Phase 02 is declared fully complete.

---

_Verified: 2026-02-26T13:00:00Z_
_Verifier: Claude (gsd-verifier)_
