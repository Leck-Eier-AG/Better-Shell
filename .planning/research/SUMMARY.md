# Project Research Summary

**Project:** Better Shell
**Domain:** POSIX-compatible reactive shell plugin with audio/visual effects and custom triggers
**Researched:** 2026-02-26
**Confidence:** MEDIUM

## Executive Summary

Better Shell is a shell enhancement plugin that makes terminals feel expressive and reactive by playing sounds, showing ASCII art, and animating spinners in response to command outcomes. The product occupies a clear gap in the ecosystem: notification-focused plugins (zsh-notify, zsh-auto-notify) handle exit codes but produce no in-terminal visuals; prompt-focused tools (oh-my-posh, powerlevel10k) style the prompt but play no audio and run no animations. No existing tool combines audio + visual art + animated spinners + custom trigger rules in a single POSIX-compatible package. The core architectural approach is established: a thin POSIX shell hook layer (using bash-preexec for bash, native add-zsh-hook for zsh) drives a trigger engine that dispatches to a Rust companion binary for audio playback and heavier rendering.

The recommended implementation strategy is a two-tier design. The shell hook layer stays as thin and POSIX-portable as possible — it captures $?, records timing, and calls the trigger engine. The companion binary (Rust, with rodio for audio and clap for CLI) handles everything pure shell cannot: non-blocking cross-platform audio, spinner animation, TOML config parsing, and the CLI for trigger setup. Config is stored as TOML for human editability and schema clarity; the binary parses it once at plugin load time and caches results in shell variables. This architecture is consistent with how production-grade shell tooling (starship, zoxide, eza) handles the boundary between shell portability and native capability.

The primary risks are architectural and must be solved in Phase 1 before any feature work begins. Hook safety (bash DEBUG trap clobbering, zsh precmd overwrite), namespace pollution, non-interactive/TTY guards, and the async-first audio pattern are all "never acceptable as shortcuts" — every one of these produces subtle, hard-to-debug breakage that only surfaces in real user environments. The pitfall research is unusually clear: all six critical pitfalls are preventable with known patterns, and all must be established in the foundation phase before audio or visual features are wired in.

## Key Findings

### Recommended Stack

The shell plugin layer must use POSIX sh with bash-preexec (0.6.0) for bash hook compatibility and zsh's native add-zsh-hook for zsh. This combination covers the broadest user base without framework lock-in. The companion binary should be Rust (stable 1.85+) using rodio 0.22.1 for audio, clap 4.5.x for CLI, serde + toml 1.0.3 for config parsing, and dirs 5.x for XDG-compliant path resolution. Development tooling centers on bats-core 1.13.0 for shell integration tests and shellcheck 0.10.x for POSIX compliance enforcement in CI. Distribution uses cargo-dist for Rust binary packaging with install script generation.

**Core technologies:**
- POSIX sh (hook layer): Shell hook entry point — only approach that covers bash and zsh without framework lock-in
- bash-preexec 0.6.0: preexec/precmd multiplexing for bash — production-proven, used by iTerm2 and Ghostty, supports bash 3.1–5.x
- add-zsh-hook (zsh native): Hook registration for zsh — Zsh Plugin Standard recommendation; safe with multiple plugins
- Rust + rodio: Companion binary for audio, spinner rendering, config parsing — single static binary, <5ms startup, non-blocking audio via rodio's background thread
- TOML (toml crate 1.0.3): Config format — unambiguous spec, native serde support, no YAML parser instability risk

### Expected Features

Better Shell's MVP must deliver audio feedback on error/success, ASCII art reactions (the primary differentiator), and all the prerequisite safety infrastructure (time thresholds, command blacklist, headless detection, global mute). Without ASCII art, Better Shell is just a reimplementation of zsh-notify. Without time thresholds and blacklist, users uninstall immediately due to noise on every trivial command.

**Must have (table stakes — v1):**
- Exit code detection via precmd hook — foundation for all reactive behavior
- Sound on error (non-zero exit) and sound on success — primary user expectation
- Default bundled sounds — out-of-box experience; no setup = instant gratification
- Configurable time threshold — prevents audio/visual spam on trivial commands like ls
- Command blacklist — man, vim, watch must never trigger; users uninstall without this
- Global enable/disable toggle — required for SSH and CI; missing = breakage in the wild
- Silent/headless auto-detection — checks $SSH_CLIENT, $TERM, $DISPLAY at startup
- ASCII art reactions on error/success — the core fun differentiator; its absence makes Better Shell redundant
- Exit code indicator in prompt — low complexity, high polish
- Source-based install — only install path; no plugin manager requirement

**Should have (competitive — v1.x):**
- Animated spinners for long-running commands — novel when integrated with the trigger system
- Custom sound file support — requested once users want personalization
- TOML config file + CLI for trigger setup — together; CLI writes, plugin reads
- Custom trigger rules (per-command pattern matching) — power-user differentiator
- Sound theming / packs and art variant randomization — polish features after core is proven

**Defer (v2+):**
- Stderr detection trigger — highest implementation complexity; requires companion binary or process substitution; only valuable if user research confirms need
- Per-project config override (direnv-style) — useful but global config satisfies most users
- Dynamic full prompt persona — deferred until base prompt segment is validated

### Architecture Approach

The architecture is a layered dispatcher: preexec/precmd hooks feed a trigger engine that routes matched events to three handlers (audio, visual, prompt themer). The companion binary sits below the shell layer and handles everything requiring a real process (audio playback, complex config parsing, spinner rendering). Config is parsed once at plugin load time and stored in shell arrays — the binary is never invoked for evaluation, only for side-effect actions. This keeps every hook invocation to pure shell logic (O(n) trigger table scan) with subprocess cost only at action dispatch time.

**Major components:**
1. Hook Dispatcher (lib/hooks.sh) — registers preexec/precmd via add-zsh-hook and bash-preexec arrays; captures $? as the absolute first operation in precmd; records timestamps
2. Trigger Engine (lib/trigger.sh) — evaluates (exit code, elapsed time, command pattern) against the loaded trigger table; routes to handlers; pure shell, no subprocesses
3. Audio Handler (lib/audio.sh) — platform detection (afplay/paplay/aplay/pw-play) cached at startup; all playback is `cmd &`; graceful no-op if no audio tool found
4. Visual Handler (lib/visual.sh) — ASCII art printed inline; spinner started as background subshell in preexec, killed by PID in precmd with terminal line clear
5. Prompt Themer (lib/prompt.sh) — PS1/RPROMPT mutation based on exit code; pure shell variable assignment; ANSI-safe
6. Config Layer (lib/config.sh) — loads TOML config via companion binary at source time; falls back to env var defaults; result cached in shell arrays
7. Companion Binary (bin/better-shell) — Rust binary: audio dispatch, config parsing, spinner rendering, CLI commands (add-trigger, list-triggers, mute)

### Critical Pitfalls

1. **Blocking operations in precmd/preexec** — any synchronous call (especially audio playback without `&`) adds perceptible latency to every prompt; always background audio with `cmd &>/dev/null &`; measure with EPOCHREALTIME; <5ms is the threshold
2. **bash DEBUG trap clobbering** — setting `trap '...' DEBUG` directly overwrites iTerm2, VSCode, and other shell integrations; always use bash-preexec's `preexec_functions+=()` arrays instead
3. **Zsh hook overwrite** — defining `precmd() { ... }` directly silently destroys other plugins' hooks; always use `add-zsh-hook precmd _bs_precmd`
4. **Namespace pollution** — generic variable or function names (e.g., `THEME`, `play_sound`) collide with user config and other plugins; prefix everything with `_bs_` (private) or `bs_` (public API); use `local` in every function
5. **Audio and visual output in non-interactive or piped contexts** — ANSI codes in piped output corrupt scripts and CI; guard with `[[ -o interactive ]] || return` and `[[ -t 1 ]] || return` at plugin top; honor `$NO_COLOR`
6. **Audio tool hardcoding** — `aplay` alone fails on PipeWire-only systems, WSL2, macOS, and headless servers; detect available tools at startup and cache the result; degrade silently to no-audio

## Implications for Roadmap

Based on research, the architecture's build order and the pitfall-to-phase mapping both point to the same four-phase structure. The pitfalls research is unusually prescriptive about timing: six of the critical pitfalls must be solved in Phase 1, before any user-visible feature is built.

### Phase 1: Foundation and Hook Infrastructure

**Rationale:** Every feature in the product depends on hooks firing correctly and safely. The pitfall research marks hook safety, namespace hygiene, and non-interactive guards as "Phase 1: Foundation" — these cannot be retrofitted. Architecture research designates Hook Dispatcher and Config Layer as the first two build targets. This phase has no user-visible output but is the entire skeleton of the plugin.

**Delivers:** A sourced shell file that registers preexec/precmd safely in both bash and zsh, captures $? correctly, records timing, enforces non-interactive/TTY guards, and exits cleanly with no output in non-interactive contexts. Namespace conventions established. bats-core test suite for hook behavior. shellcheck passing on all shell files.

**Addresses features:** Exit code detection, source-based install, global enable/disable toggle (as a guard pattern), silent/headless auto-detection skeleton

**Avoids:** DEBUG trap clobbering (Bash), Zsh hook overwrite, namespace pollution, visual output in piped contexts — all must be solved here

**Research flag:** Standard patterns — bash-preexec and add-zsh-hook are well-documented; no additional research phase needed

---

### Phase 2: Audio Integration

**Rationale:** Audio is the first user-visible feature and the one most likely to cause environmental breakage. The pitfall research explicitly maps audio tool detection, WSL2 silence, and the mute option to Phase 2. Audio must be built with the fallback chain, headless detection, and `BETTER_SHELL_NO_AUDIO=1` from the start — not retrofitted.

**Delivers:** Non-blocking audio playback on error and success, with afplay/paplay/aplay/pw-play detection cached at startup, graceful no-op in environments without audio tools, `BETTER_SHELL_NO_AUDIO` env var, `bs_mute`/`bs_unmute` CLI commands, and default bundled sound files.

**Uses:** Rust companion binary (rodio 0.22.1) for cross-platform audio; lib/audio.sh for shell-side dispatch; sounds/ directory for bundled defaults

**Addresses features:** Sound on error, sound on success, default bundled sounds, cross-platform audio playback, non-blocking audio, global mute

**Avoids:** Audio tool hardcoding, synchronous audio in hooks, audio spam without time threshold (implement threshold here), audio in WSL2/SSH/headless environments

**Research flag:** Standard patterns for audio dispatch and fallback chain — no additional research needed. Threshold default value (recommend 5s) may need tuning based on user feedback.

---

### Phase 3: Visual Effects and Prompt Theming

**Rationale:** Visual features depend on hooks working correctly (Phase 1) and can be developed independently of audio (Phase 2). The architecture build order places Visual Handler and Prompt Themer at steps 4 and 6. The pitfall research maps visual output guards and NO_COLOR compliance to Phase 3. ASCII art is the primary differentiator — this phase is where Better Shell becomes distinctly itself.

**Delivers:** ASCII art reactions printed inline on error/success, animated spinner started in preexec and killed cleanly in precmd, exit code indicator in PS1/RPROMPT, NO_COLOR compliance, narrow terminal fallback for art rendering ($COLUMNS check), tmux/screen safety.

**Uses:** lib/visual.sh, lib/prompt.sh; art/ directory for bundled default art; background subshell spinner pattern (preexec stores PID, precmd kills by PID + clears line)

**Addresses features:** ASCII art reactions on error/success, animated spinners, exit code indicator in prompt, art variant randomization (add multiple art files in art/)

**Avoids:** ANSI codes in non-TTY contexts, NO_COLOR violations, spinner zombie processes (kill by PID in precmd), art breaking narrow terminals

**Research flag:** Standard patterns for spinner and ANSI rendering — no additional research needed. ASCII art content/aesthetics are a creative decision not requiring research.

---

### Phase 4: Config File, Trigger Rules, and CLI

**Rationale:** Custom trigger rules are the power-user differentiator but require the config layer and companion binary CLI to exist. Architecture research explicitly defers config file parsing to step 8 and CLI commands to step 9. This phase cannot start until Phases 1-3 are stable because it wires together all handlers via the trigger engine.

**Delivers:** TOML config file at XDG_CONFIG_HOME/better-shell/config.toml, trigger table parsed by companion binary at source time and cached in shell arrays, per-command pattern matching (git push → specific sound), `better-shell add-trigger` / `better-shell list-triggers` CLI commands, sound theming/packs via config, custom sound file support.

**Uses:** Rust companion binary (clap 4.5.x for CLI, serde + toml 1.0.3 for parsing, dirs 5.x for XDG paths); lib/config.sh; lib/trigger.sh for rule evaluation engine

**Addresses features:** TOML config file, CLI for trigger setup, custom trigger rules, custom sound file support, sound theming/packs

**Avoids:** Invoking companion binary on every hook call (parse config once at source time, cache in arrays); eval on user-supplied config values (parse strictly); dual YAML/TOML support (TOML only)

**Research flag:** Config schema design and trigger rule syntax need decisions during planning. The Rust binary's CLI surface (subcommands, flags) should be specced before implementation. Consider a planning research spike on TOML schema patterns for trigger rules.

---

### Phase Ordering Rationale

- **Foundation before everything:** All six critical pitfalls that are categorized as "never acceptable shortcuts" manifest in hook registration and output guarding. Retrofitting these after features exist is rated MEDIUM to HIGH recovery cost in pitfall research.
- **Audio before visuals:** Audio involves environmental detection (WSL2, macOS, PipeWire) that is orthogonal to visual rendering. Isolating audio in Phase 2 allows it to be tested in minimal environments (Docker) before visual complexity is added.
- **Visuals before config:** The visual handler is statically wired (error → error art, success → success art) with no config dependency. Building it before the config layer lets Phase 3 be tested end-to-end without the trigger engine being complete.
- **Config and CLI last:** The trigger engine wires together all existing handlers. It is inherently an integration phase. Building it last means all the pieces it integrates are individually proven.
- **Feature dependency graph confirms this order:** FEATURES.md dependency tree shows exit code detection as root, then handlers (audio, visual, prompt), then config/trigger rules, then CLI. The phase order directly follows this tree.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4:** Trigger rule schema design — no existing shell plugin has a config-driven per-command trigger system; the TOML schema for expressing (command pattern + exit code + duration) → (audio + visual action) mappings is novel and needs careful design before implementation

Phases with standard patterns (skip research-phase):
- **Phase 1:** bash-preexec and add-zsh-hook are thoroughly documented; hook array registration is a known pattern
- **Phase 2:** Audio fallback chain (afplay/paplay/aplay) is a documented pattern with real-world implementations (Claude Code hooks, zsh-notify)
- **Phase 3:** Spinner PID management and ANSI rendering patterns are well-documented; NO_COLOR standard is stable

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | Core hook approach is HIGH confidence (official docs, production plugins); Rust binary choice is MEDIUM (strong ecosystem pattern, one low-confidence source on Go vs Rust tradeoffs) |
| Features | MEDIUM | Feature expectations verified across multiple plugins; MVP definition is synthesis from ecosystem patterns; no user research data |
| Architecture | MEDIUM | Hook mechanisms are HIGH confidence from official docs; trigger/config system is novel and inferred from analogues (starship, direnv); companion binary boundary is well-reasoned but unvalidated |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls verified from official sources (ShellCheck, Zsh docs, bash-preexec issues); UX pitfalls from community sources; performance thresholds from real issue reports |

**Overall confidence:** MEDIUM

### Gaps to Address

- **Trigger rule schema:** The TOML config schema for custom trigger rules is the most novel part of the design. No direct analogues exist. The schema needs to be designed during Phase 4 planning, ideally with a prototype before committing to the structure. Flag for research spike.
- **Audio format support:** FEATURES.md notes WAV and MP3 support via rodio/Symphonia. OGG and FLAC are also supported. The bundled sound files should be WAV for maximum compatibility; the format decision for user-supplied files should be documented explicitly.
- **Spinner and audio concurrency:** If a command is long enough to show a spinner and also triggers an audio event, the interaction between spinner cleanup (precmd kills PID, clears line) and audio dispatch (async subprocess) needs explicit ordering in the implementation. The architecture outlines this but the exact sequencing needs to be coded carefully.
- **bash-preexec "source last" requirement:** bash-preexec must be sourced last in .bashrc. Better Shell's bash entry point must document this constraint and ideally detect misloading. How to communicate this to users at install time is unresolved.
- **MVP sound file licensing:** Bundled sounds need permissive licensing (CC0 or equivalent). Source of bundled audio is unresolved — this is a non-technical gap but blocks the "default bundled sounds" MVP requirement.

## Sources

### Primary (HIGH confidence)
- [bash-preexec GitHub — rcaloras](https://github.com/rcaloras/bash-preexec) — version 0.6.0, hook array pattern, DEBUG trap caveats, source-last requirement
- [Zsh Plugin Standard — wiki.zshell.dev](https://wiki.zshell.dev/community/zsh_plugin_standard) — add-zsh-hook recommendation, namespace conventions, plugin path handling
- [rodio docs.rs 0.22.1](https://docs.rs/rodio/latest/rodio/) — audio playback capabilities, cross-platform support
- [toml crate docs.rs 1.0.3](https://docs.rs/toml/latest/toml/) — TOML parsing in Rust
- [bats-core v1.13.0 releases](https://github.com/bats-core/bats-core/releases) — shell integration testing
- [ShellCheck SC3047](https://www.shellcheck.net/wiki/SC3047) — POSIX trap limitations
- [Zsh hook system — official docs](https://zsh.sourceforge.io/Doc/Release/Functions.html) — hook registration
- [NO_COLOR standard](https://no-color.org/) — ANSI opt-out convention

### Secondary (MEDIUM confidence)
- [zsh-notify (marzocchi)](https://github.com/marzocchi/zsh-notify) — feature set, audio architecture, platform support
- [zsh-auto-notify (MichaelAquilina)](https://github.com/MichaelAquilina/zsh-auto-notify) — blacklist/threshold design patterns
- [oh-my-posh](https://github.com/JanDeDobbeleer/oh-my-posh) — prompt segment design, cross-shell binary architecture
- [Sound effects for Claude Code hooks — alexop.dev](https://alexop.dev/posts/how-i-added-sound-effects-to-claude-code-with-hooks/) — real-world afplay/aplay/paplay pattern
- [Amazon Q CLI Issue #844](https://github.com/aws/amazon-q-developer-cli/issues/844) — 11ms hook latency complaint as performance threshold reference
- [bash-preexec Issue #39](https://github.com/rcaloras/bash-preexec/issues/39) — DEBUG trap preservation
- [Shopify/hookbook](https://github.com/Shopify/hookbook) — cross-shell hook alternative
- [revolver ZSH spinner](https://github.com/molovo/revolver) — spinner implementation pattern
- [How to Write Better Bash Spinners — willcarh.art](https://willcarh.art/blog/how-to-write-better-bash-spinners) — spinner cursor management

### Tertiary (LOW confidence)
- [Building Great CLIs in 2025 — Medium](https://medium.com/@no-non-sense-guy/building-great-clis-in-2025-node-js-vs-go-vs-rust-e8e4bf7ee10e) — Rust vs Go tradeoffs; single article, consistent with broader ecosystem signal but not authoritative

---
*Research completed: 2026-02-26*
*Ready for roadmap: yes*
