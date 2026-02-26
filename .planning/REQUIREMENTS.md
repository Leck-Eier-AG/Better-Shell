# Requirements: Better Shell

**Defined:** 2026-02-26
**Core Value:** The shell should feel alive — every command gets a reaction, turning the terminal from a silent tool into an expressive experience.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Hook Infrastructure

- [x] **HOOK-01**: Shell hooks (preexec/precmd) detect command start, end, and exit code across bash and zsh
- [x] **HOOK-02**: Plugin installs via single `source` line in rc file
- [x] **HOOK-03**: Auto-detect SSH/headless/CI environments and disable audio/visuals
- [x] **HOOK-04**: Global enable/disable toggle via command and config

### Audio

- [x] **AUD-01**: Play configurable sound on non-zero exit code (error)
- [x] **AUD-02**: Play configurable sound on success (zero exit code)
- [ ] **AUD-03**: Ship default bundled sound files (error beep, success chime)
- [ ] **AUD-04**: Allow user-provided custom sound files (.wav/.mp3)
- [x] **AUD-05**: Cross-platform audio playback (afplay/aplay/paplay detection)
- [x] **AUD-06**: All audio playback is non-blocking (async)
- [x] **AUD-07**: Configurable time threshold (skip sounds for trivial commands)
- [x] **AUD-08**: Command blacklist (never trigger on vim, man, watch, etc.)
- [ ] **AUD-09**: Sound packs/themes with one-command swap (retro, minimal, dramatic)
- [ ] **AUD-10**: Detect and trigger on stderr output

### Visuals

- [ ] **VIS-01**: ASCII art reactions displayed on error and success
- [ ] **VIS-02**: Random art variant selection from a library per event
- [ ] **VIS-03**: Animated spinner for long-running commands (start on preexec, stop on precmd)
- [ ] **VIS-04**: Prompt exit code indicator (✓/✘ with color)

### Configuration

- [ ] **CFG-01**: TOML config file for all settings (triggers, sounds, visuals, thresholds)
- [ ] **CFG-02**: CLI commands for quick setup (add-trigger, set-theme, enable/disable)
- [ ] **CFG-03**: Custom trigger rules matching command patterns to specific sounds/art
- [ ] **CFG-04**: All options configurable via both CLI commands and config file

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Triggers

- **TRIG-01**: Per-project config override (direnv-style .better-shell file)
- **TRIG-02**: Dynamic prompt theme with full persona (animated/complex theming)

## Out of Scope

| Feature | Reason |
|---------|--------|
| GUI configuration tool | Contradicts terminal-native identity; massive dependency surface |
| Background / ambient music | Universally annoying; breaks focus; clashes with user's music |
| Desktop OS notifications (popups) | Adds OS-level dependency; zsh-notify already owns this space |
| Real-time progress bars with percentage | Shell can't know internal progress of arbitrary commands |
| Remote / networked sound playback | Significantly complex; SSH sessions auto-disable audio instead |
| Plugin marketplace for sounds/art | Server infrastructure complexity wildly exceeds value at this stage |
| Persistent error history / analytics | Privacy concern; turns fun plugin into surveillance tool |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| HOOK-01 | Phase 1 | Complete |
| HOOK-02 | Phase 1 | Complete |
| HOOK-03 | Phase 1 | Complete |
| HOOK-04 | Phase 1 | Complete |
| AUD-01 | Phase 2 | Complete |
| AUD-02 | Phase 2 | Complete |
| AUD-03 | Phase 2 | Pending |
| AUD-04 | Phase 2 | Pending |
| AUD-05 | Phase 2 | Complete |
| AUD-06 | Phase 2 | Complete |
| AUD-07 | Phase 2 | Complete |
| AUD-08 | Phase 2 | Complete |
| AUD-09 | Phase 2 | Pending |
| AUD-10 | Phase 2 | Pending |
| VIS-01 | Phase 3 | Pending |
| VIS-02 | Phase 3 | Pending |
| VIS-03 | Phase 3 | Pending |
| VIS-04 | Phase 3 | Pending |
| CFG-01 | Phase 4 | Pending |
| CFG-02 | Phase 4 | Pending |
| CFG-03 | Phase 4 | Pending |
| CFG-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-02-26*
*Last updated: 2026-02-26 after 01-02 completion — HOOK-04 complete, all Phase 1 requirements done*
