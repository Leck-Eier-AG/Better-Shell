---
status: testing
phase: 02-audio
source: [02-UAT.md (gap re-verification)]
started: 2026-02-26T14:00:00Z
updated: 2026-02-26T14:00:00Z
---

## Current Test

number: 1
name: Error sound on failed command (re-test)
expected: |
  Source better-shell.sh in a terminal. Run `false`. You should hear an error sound immediately — no delay, no silence. The sound should play even though `false` completes instantly (under 1s).
awaiting: user response

## Tests

### 1. Error sound on failed command (re-test)
expected: Source better-shell.sh in a terminal. Run `false`. You should hear an error sound immediately — no delay, no silence. The sound should play even though `false` completes instantly (under 1s).
result: [pending]

### 2. No job control messages in terminal (re-test)
expected: Run `sleep 2` and wait for the success sound to finish playing. Watch the terminal — there should be NO `[N] done ...` messages appearing at any point. The terminal should stay completely clean.
result: [pending]

### 3. Sound pack error sounds work (re-test)
expected: Run `bsh sound-pack chill`, then run `false`. You should hear a chill-style error sound. Try `bsh sound-pack retro` then `false` — different retro-style error sound. Each pack should have its own distinct error sound.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0

## Gaps

[none yet]
