---
status: diagnosed
phase: 02-audio
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md]
started: 2026-02-26T12:00:00Z
updated: 2026-02-26T12:15:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Audio plays after long command
expected: Source better-shell in a terminal. Run `sleep 2`. After it finishes, you should hear a success sound play before/at the next prompt.
result: pass

### 2. No sound on quick success
expected: Run `echo hi` — no sound should play (command duration < 1s threshold).
result: pass

### 3. Error sound on failed command
expected: Run `false` or any command that fails. You should hear an error sound (different tone from success).
result: issue
reported: "no sound, when i run \"false\" or any other command that fails"
severity: major

### 4. Sound pack switching
expected: Run `bsh sound-pack retro` — should confirm pack changed. Then run `sleep 2` — sound should have a different character (chiptune/retro). Try `bsh sound-pack chill` and `bsh sound-pack meme` similarly.
result: issue
reported: "chill soundpack has no fail sounds. sleep 2 gives a pling"
severity: major

### 5. Volume control
expected: Run `bsh volume 20` — should confirm volume changed. Run `sleep 2` — sound should be noticeably quieter. Run `bsh volume 80` — sound should be louder.
result: pass

### 6. Bundled sound packs present
expected: Run `ls sounds/` from the better-shell directory. You should see 3 pack directories: meme, chill, retro. Each should contain error/, success/, warning/ subdirectories with light.wav, medium.wav, heavy.wav files.
result: pass

### 7. Non-blocking playback
expected: After `sleep 2`, the prompt should return immediately — the sound plays in the background without delaying your next input.
result: issue
reported: "it doesn't block my input, but it shows \"[2]  + 413592 done       ( set +m; case \"$_BSH_AUDIO_TOOL\" in (pw-play) pw-play  \"$file\" > /dev/null 2\" in the terminal. it should be completely silent and hidden, so it doesn't annoy the user."
severity: major

### 8. Intensity scaling by duration
expected: Run `sleep 2` (light intensity, short beep). Then run `sleep 15` (medium intensity, longer/richer sound). The two sounds should differ — medium should be more prominent than light.
result: pass

## Summary

total: 8
passed: 5
issues: 3
pending: 0
skipped: 0

## Gaps

- truth: "Error sound plays on failed command"
  status: failed
  reason: "User reported: no sound, when i run \"false\" or any other command that fails"
  severity: major
  test: 3
  root_cause: "Threshold check at lib/audio.sh:181 fires before event-type determination. `false` completes in 0s < 1s threshold, so function returns before checking exit code. Error events should bypass threshold."
  artifacts:
    - path: "lib/audio.sh"
      issue: "Line 181: threshold gate is unconditional, blocks error events"
  missing:
    - "Exempt error events (non-zero _BSH_LAST_EXIT) from duration threshold, or move threshold check after event-type determination"
  debug_session: ".planning/debug/error-sound-never-plays.md"

- truth: "Sound pack switching works for all packs including error sounds"
  status: failed
  reason: "User reported: chill soundpack has no fail sounds. sleep 2 gives a pling"
  severity: major
  test: 4
  root_cause: "Same root cause as test 3 — error sounds never trigger because threshold gate blocks before event type is determined. Sound files exist in all packs (chill/error/*.wav confirmed present)."
  artifacts:
    - path: "lib/audio.sh"
      issue: "Line 181: threshold gate prevents error event determination"
  missing:
    - "Fix threshold ordering (same fix as test 3)"
  debug_session: ".planning/debug/error-sound-never-plays.md"

- truth: "Background audio playback is completely silent in terminal (no job control messages)"
  status: failed
  reason: "User reported: it doesn't block my input, but it shows \"[2]  + 413592 done       ( set +m; case \"$_BSH_AUDIO_TOOL\" in (pw-play) pw-play  \"$file\" > /dev/null 2\" in the terminal. it should be completely silent and hidden, so it doesn't annoy the user."
  severity: major
  test: 7
  root_cause: "set +m is inside the backgrounded subshell (lib/audio-player.sh:109) but only affects the child process. Parent zsh still has monitor mode ON, tracks the ( ... ) & job, and prints [N] done notification. disown has a race condition — job can finish before disown executes."
  artifacts:
    - path: "lib/audio-player.sh"
      issue: "Lines 91-108: set +m in wrong process (child instead of parent)"
  missing:
    - "Move set +m to parent shell context before backgrounding, then restore set -m after disown"
  debug_session: ".planning/debug/job-control-leak.md"
