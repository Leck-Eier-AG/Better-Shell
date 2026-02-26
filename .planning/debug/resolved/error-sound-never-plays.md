---
status: resolved
trigger: "Investigate why failed commands (e.g., false, non-existent commands) produce no error sound"
created: 2026-02-26T00:00:00Z
updated: 2026-02-26T12:30:00Z
---

## Current Focus

hypothesis: Threshold check on line 181 of audio.sh blocks ALL error events from quick commands because it fires before the event-type determination on line 189
test: Trace decision chain for `false` (exit=1, duration=0)
expecting: Threshold gate returns early, error event logic never reached
next_action: Report root cause

## Symptoms

expected: Running `false` or a non-existent command should play an error sound
actual: No error sound plays; success sounds work after `sleep 2`
errors: None (silent failure by design — early return)
reproduction: Run `false` in shell with Better-Shell loaded
started: By design — threshold has always gated errors

## Eliminated

(none needed — root cause found on first pass)

## Evidence

- timestamp: 2026-02-26T00:00:00Z
  checked: lib/audio.sh _bsh_audio_trigger decision flow (lines 168-207)
  found: |
    Line 181: `[[ "${_BSH_CMD_DURATION:-0}" -lt "${_BSH_AUDIO_THRESHOLD:-1}" ]] && return 0`
    This threshold check runs BEFORE the event-type determination on lines 189-195.
    For `false`, duration=0 which is < threshold=1, so the function returns immediately.
    The error event logic on line 189 (`_BSH_LAST_EXIT -ne 0`) is never reached.
  implication: The threshold gate is event-type-agnostic — it blocks errors and successes equally

- timestamp: 2026-02-26T00:00:00Z
  checked: lib/hooks.sh _bsh_precmd (lines 37-65)
  found: |
    _BSH_LAST_EXIT is correctly captured as first operation (line 39-45).
    _BSH_CMD_DURATION is correctly calculated (line 49).
    Both values are available when _bsh_audio_trigger is called on line 61.
  implication: Hook infrastructure is correct; problem is in audio.sh decision logic

- timestamp: 2026-02-26T00:00:00Z
  checked: Success sound behavior with `sleep 2`
  found: |
    `sleep 2` has exit=0 and duration=2. Duration 2 >= threshold 1, so it passes
    the gate. Event resolves to "success". This confirms the threshold is the gate.
  implication: Success sounds work only because long commands exceed threshold

## Resolution

root_cause: |
  In lib/audio.sh line 181, the duration threshold check is applied unconditionally
  to ALL commands before the event type is determined. Error commands like `false`
  or typos complete in 0 seconds (duration=0). Since 0 < 1 (default threshold),
  the function returns early on line 181 and NEVER reaches the error event
  determination on line 189. The threshold was designed to filter trivial
  successes but it inadvertently filters all fast-failing commands too.

fix: (not applied — diagnosis only)
verification: (not applied — diagnosis only)
files_changed: []
