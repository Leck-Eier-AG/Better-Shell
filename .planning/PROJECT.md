# Better Shell

## What This Is

A POSIX-compatible shell plugin that makes the terminal fun and reactive. It plays sounds on errors and successes, shows ASCII art reactions, provides animated spinners for long-running commands, and offers dynamic prompt themes — all configurable through a config file or CLI commands.

## Core Value

The shell should feel alive — every command gets a reaction, turning the terminal from a silent tool into an expressive experience.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Play sounds on non-zero exit codes (error detection)
- [ ] Play sounds when stderr output is detected
- [ ] Play sounds on command success
- [ ] Ship built-in default sound files (beeps, chimes, etc.)
- [ ] Allow users to provide their own sound files (.wav/.mp3)
- [ ] Show ASCII art reactions on error and success
- [ ] Animated spinners/progress indicators for long-running commands
- [ ] Dynamic prompt theme that reacts to last command result
- [ ] User-defined custom trigger rules (e.g. play X when git push completes)
- [ ] YAML/TOML config file for mapping triggers to actions
- [ ] CLI commands for quick trigger setup (e.g. `better-shell add-trigger --on error --play boom.wav`)
- [ ] Install via sourcing in .bashrc/.zshrc

### Out of Scope

- GUI configuration tool — terminal-native only
- Background music / ambient sounds — focus on reactive events
- Remote/networked sound playback — local only

## Context

- Must work across POSIX shells (bash, zsh, sh, etc.)
- Hooks into shell via `source` in rc files
- Needs a companion binary or script for audio playback and spinner rendering — pure shell can't handle audio
- Sound playback depends on platform audio tools (aplay, afplay, paplay, etc.)
- ASCII art and ANSI escape codes for visual effects
- Trigger system needs to intercept command exit codes and stderr without breaking normal shell flow

## Constraints

- **Compatibility**: Must work on any POSIX-compliant shell — no zsh-only or bash-only features in core hooks
- **Performance**: Shell hooks must add negligible latency — audio/visuals should be async/non-blocking
- **Dependencies**: Minimize external dependencies — leverage system audio tools where possible
- **Install simplicity**: Single `source` line in rc file — no complex setup

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| POSIX shell compatibility over single-shell features | Broadest user base, works everywhere | — Pending |
| Config file + CLI for configuration | Power users get YAML/TOML, casual users get CLI commands | — Pending |
| Ship default sounds + allow custom | Good out-of-box experience while being customizable | — Pending |
| Source-based installation | Simplest install path, no package manager dependency | — Pending |

---
*Last updated: 2026-02-26 after initialization*
