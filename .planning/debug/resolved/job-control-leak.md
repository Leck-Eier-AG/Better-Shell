---
status: resolved
trigger: "background audio playback leaks job control messages like [2] + done to terminal"
created: 2026-02-26T00:00:00Z
updated: 2026-02-26T12:30:00Z
---

## Current Focus

hypothesis: "set +m inside the subshell only affects the child; the PARENT shell (zsh interactive) still has monitor mode ON and prints the job completion notification when the backgrounded subshell exits"
test: confirmed by code reading — set +m is inside ( ... ) & which is a child process
expecting: parent zsh still tracks the job and prints Done notification
next_action: report root cause

## Symptoms

expected: Audio plays silently in background with no terminal output
actual: Job completion messages like `[2]  + 413592 done  ( set +m; ... )` appear at the zsh prompt
errors: Not errors per se — zsh job notification output to terminal
reproduction: Any command that triggers audio playback (duration >= threshold)
started: Since audio playback was implemented

## Eliminated

- hypothesis: "disown is not being called"
  evidence: disown $! 2>/dev/null is present at line 108 of lib/audio-player.sh (line 725 in built file). However disown in zsh behaves differently — see Evidence.
  timestamp: 2026-02-26

## Evidence

- timestamp: 2026-02-26
  checked: _bsh_play_sound function in lib/audio-player.sh lines 82-111
  found: |
    Pattern is:
      ( set +m; case ... esac ) &
      disown $! 2>/dev/null
    The `set +m` is INSIDE the subshell (child process). It disables job control
    for the CHILD, which is irrelevant — the child is the one being monitored,
    not the one doing the monitoring. The PARENT interactive shell still has
    `monitor` mode ON and still tracks the background job.
  implication: set +m in the wrong process — must be in the parent

- timestamp: 2026-02-26
  checked: zsh job control behavior vs bash
  found: |
    In zsh, `disown` removes the job from the job table but zsh may have already
    queued the "done" notification before disown executes. The race is:
      1. ( ... ) & — zsh adds job to job table, prints [N] PID
      2. disown $! — removes from job table (if fast enough)
      3. Job completes — if notification was already queued, zsh prints it

    More critically: zsh's `disown` does NOT suppress the completion notification
    for jobs that have already been waited on or whose status has been collected.
    For very short-lived background jobs (audio playback can complete in <1s),
    the job may finish before or nearly simultaneously with disown.

    Additionally, in zsh, `disown` without `-a` on a specific PID still leaves
    the shell aware of the process completion via SIGCHLD handling that was set
    up when the job was first backgrounded.
  implication: disown alone is not reliable in zsh for suppressing done messages

- timestamp: 2026-02-26
  checked: calling context — _bsh_precmd -> _bsh_audio_trigger -> _bsh_play_sound
  found: |
    _bsh_play_sound is called from _bsh_precmd (via _bsh_audio_trigger), which
    runs as a zsh precmd hook. This means it executes in the MAIN interactive
    shell with full job control (monitor mode) enabled. The ( ... ) & creates a
    job that zsh's job table tracks. The `set +m` inside the subshell is a no-op
    for this problem — it only affects the subshell's own children, not the
    parent's tracking of the subshell itself.
  implication: The fix must disable monitor mode in the PARENT before backgrounding

## Resolution

root_cause: |
  `set +m` is executed INSIDE the backgrounded subshell at lib/audio-player.sh:109
  (line 709 in the built better-shell.sh). This is architecturally wrong.

  Job control notifications ("[N] done ...") are printed by the PARENT shell
  (the interactive zsh session), not by the child. The parent has `monitor` mode
  ON (default for interactive shells). When the parent executes `( ... ) &`, it:
    1. Adds the subshell to its job table
    2. Prints the job number and PID (e.g., "[2] 413592")
    3. Later, when the job completes, prints the "done" notification

  `set +m` inside the child only prevents the CHILD from printing job
  notifications for ITS OWN children — it has zero effect on the parent's
  tracking of the subshell itself.

  `disown $! 2>/dev/null` (line 108 / 725) is the right idea but has a race
  condition: for short-lived audio commands, the job may complete before disown
  runs, or zsh may have already collected the exit status via SIGCHLD.

  The correct pattern is:
    1. Disable monitor mode in the PARENT before backgrounding:
         set +m
         ( pw-play ... >/dev/null 2>&1 ) &
         disown $! 2>/dev/null
         set -m
    2. Or use a fully detached approach that never enters the job table:
         { pw-play ... >/dev/null 2>&1 & } 2>/dev/null
    3. Or redirect the job control output specifically:
         ( pw-play ... >/dev/null 2>&1 & ) 2>/dev/null

  Option 1 (set +m in parent, background, set -m) is the most robust and explicit.

fix: (not applied — diagnosis only)
verification: (not applied)
files_changed: []
