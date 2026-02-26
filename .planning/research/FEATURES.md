# Feature Research

**Domain:** Shell enhancement / fun terminal plugin (audio + visual effects)
**Researched:** 2026-02-26
**Confidence:** MEDIUM — core feature expectations verified across multiple plugins and community sources; some UX conclusions are synthesis from patterns across ecosystem

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Exit code detection (error/success) | Every shell enhancement plugin does this; it is the foundational signal | LOW | `$?` in precmd hook; bash-preexec for bash compat |
| Sound on error (non-zero exit) | The single most-requested shell feedback feature; zsh-notify, auto-notify, and Claude Code hooks all implement this as their primary event | LOW | Requires async execution (`&`) to not block shell |
| Sound on success | Counterpart to error; users expect symmetry | LOW | Need a configurable threshold to avoid noise on every `ls` |
| Default bundled sounds | Users won't set up sounds themselves on first run; out-of-box experience must work | LOW | Ship a small set: error beep, success chime. Keep files small. |
| Custom sound file support | Every mature notify plugin offers this | LOW | Accept `.wav` / `.mp3`; delegate to system player |
| Cross-platform audio playback | Users are on macOS, Linux; SSH sessions are common | MEDIUM | `afplay` (macOS), `aplay`/`paplay` (Linux); detect at runtime |
| Non-blocking audio playback | Blocking the prompt while sound plays destroys UX | LOW | Always background with `&`; document this clearly |
| Source-based install | Shell plugins are sourced in rc files; any other install path creates friction | LOW | Single `source ~/.better-shell/better-shell.sh` line |
| Exit code in prompt | Users of bash-git-prompt, oh-my-posh, powerlevel10k all see exit status in prompt; expected by power users | LOW | Color or symbol change; ✘ for failure, ✓ for success |
| Configurable time threshold | zsh-notify defaults to 30s; auto-notify to 10s; every plugin has this | LOW | Don't trigger success sound on trivial commands |
| Command blacklist / ignore list | Needed from day 1; `watch`, `man`, `vim` should never trigger notifications | LOW | Simple array/list in config; regex support is a plus |
| Global enable/disable toggle | `disable_better_shell` / `enable_better_shell` — zsh-auto-notify ships this | LOW | Critical for headless and SSH sessions |
| Silent/headless detection | Triggering audio over SSH or in CI is a known pitfall; must auto-detect or respect a flag | MEDIUM | Check `$SSH_CLIENT`, `$TERM`, `$DISPLAY`; expose `BETTER_SHELL_SILENT` env var |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| ASCII art reactions on error/success | No shell notification plugin does visual art reactions — this is the core fun/expressive identity of Better Shell | MEDIUM | Use ANSI escape codes; keep art small enough not to scroll off screen; needs a library of art variants |
| Animated spinners for long-running commands | Existing spinner libs (revolver, bash-spinner) are standalone scripts, not integrated with a trigger system; bundling them together is new | MEDIUM | Needs preexec hook to start spinner, precmd to stop; spinner must be drawn in-line without clobbering output |
| Dynamic prompt theme reacting to last command | oh-my-posh and powerlevel10k do git-aware prompts; none react to general command outcomes with *visual character* — a "happy" vs "sad" prompt persona is novel | MEDIUM | Segment-style; show different emoji/symbol/color depending on `$?` |
| Stderr detection trigger | zsh-notify only triggers on exit code; Better Shell also triggers on stderr output — this is a meaningful UX difference for commands that exit 0 but print warnings | HIGH | Requires capturing stderr without breaking normal output; complex in POSIX shell; may need companion binary |
| Custom trigger rules (per-command / per-pattern) | No existing notify plugin lets you say "play X when git push completes"; this is the power-user differentiator | HIGH | Requires config file + matching logic; pattern match on command string + exit code combo |
| YAML/TOML config file | Most plugins use environment variables for config; a structured config file is more discoverable, composable, and version-controllable | MEDIUM | TOML is the right call — simpler than YAML, no indentation ambiguity; requires a parser (pure shell or companion binary) |
| CLI for trigger setup | `better-shell add-trigger --on error --play boom.wav` lowers the barrier for casual users who don't want to edit config files | MEDIUM | Shell function or companion binary; writes to config file |
| Sound theming / packs | One-command swap between "retro", "minimal", "dramatic" sound packs | LOW | Trivial once bundled sounds exist; high perceived value for personality/fun angle |
| Art variant randomization | Show a random ASCII art from a set on each error — keeps the experience fresh, not annoying | LOW | Requires a library of art; random selection in shell is trivial |
| Per-project config override | direnv-style `.better-shell` file in a project dir to override global config | MEDIUM | Adds discoverability; load on `chpwd` hook; security concern (auto-trust is bad) |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| GUI configuration tool | Easier config for non-technical users | Contradicts the terminal-native identity; adds a massive dependency surface; shell plugin users don't want GUIs | Invest in CLI commands (`better-shell add-trigger`) and good docs; config file with comments |
| Background / ambient music | "Make the shell feel alive all the time" | Constant audio is universally annoying; breaks focus; clashes with user's own music; no existing tool does this for a reason | Stick to reactive event sounds only; sounds tied to meaningful outcomes earn attention |
| Real-time progress bars with percentage | Users expect ETAs for long commands | Shell has no way to know internal progress of an arbitrary command; fake/indeterminate bars are better UX than inaccurate bars | Use animated spinners (indeterminate) — honest about unknown progress |
| Remote / networked sound playback | Sound notifications on a remote machine | Significantly complex (SSH forwarding, network protocols); out of scope; no comparable tool does this | Document that SSH sessions auto-disable audio; local-only is the right scope |
| Desktop system notifications (OS popups) | Terminal is in background; miss the sound | Requires `terminal-notifier` (macOS) / `notify-send` (Linux); adds an OS-level dependency and permission surface that the project explicitly avoids | If a user wants desktop notifications, point them to zsh-notify/zsh-auto-notify; Better Shell owns the in-terminal experience |
| Plugin manager / marketplace for sounds and art | "Users can share packs" | Requires server infrastructure, curation, versioning — all for a fun shell plugin; complexity wildly exceeds value at this stage | Ship opinionated defaults; let users add local files; revisit in v2+ if demand is clear |
| Persistent history / analytics of errors | "See which commands fail most" | Privacy concern; turns a fun plugin into a surveillance tool; adds storage complexity | Not in scope; out-of-scope permanently unless user explicitly requests opt-in analytics |

---

## Feature Dependencies

```
[Exit code detection (precmd hook)]
    └──requires──> [Error sound]
    └──requires──> [Success sound]
    └──requires──> [ASCII art reactions]
    └──requires──> [Dynamic prompt theme]
    └──requires──> [Custom trigger rules] (exit-code-based triggers)

[Spinner / progress indicator]
    └──requires──> [preexec hook] (start spinner)
    └──requires──> [precmd hook] (stop spinner)

[Custom trigger rules]
    └──requires──> [Config file parsing]
    └──requires──> [Exit code detection]
    └──enhances──> [Stderr detection] (stderr-triggered rules)

[CLI for trigger setup]
    └──requires──> [Config file parsing]
    └──writes-to──> [Config file]

[Sound theming / packs]
    └──requires──> [Default bundled sounds]

[Art variant randomization]
    └──requires──> [ASCII art reactions]

[Per-project config override]
    └──requires──> [Config file parsing]
    └──requires──> [chpwd hook]

[Stderr detection trigger]
    └──conflicts──> [POSIX shell purity]
    (requires process substitution or companion binary; cannot be done purely in POSIX sh)

[Silent/headless detection]
    └──enhances──> [Global enable/disable toggle]
    (auto-disables audio/visuals; toggle is the manual form of the same behavior)
```

### Dependency Notes

- **Exit code detection requires precmd/preexec hooks:** Zsh has these natively; bash requires `bash-preexec` (rcaloras/bash-preexec) which is battle-tested (used by iTerm2, Ghostty). POSIX `sh` has no hook mechanism — must use `PROMPT_COMMAND` in bash or accept that sh compatibility for hooks is limited.
- **Spinner requires both hooks:** preexec starts the spinner before the command runs; precmd stops it after. Without both, the spinner either never starts or never stops.
- **Stderr detection conflicts with POSIX purity:** Intercepting stderr without losing it requires `exec 2> >(tee ...)` style redirection or a wrapper binary. This is the highest-complexity feature and should be deferred until core works.
- **Custom trigger rules requires config file:** The trigger matching logic must read from the config; the CLI writes to it. Both depend on the config parser existing first.
- **Silent mode is a prerequisite for all audio/visual features:** It must be established before audio plays or art prints — not retrofitted later.

---

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Exit code detection via precmd hook — the foundational mechanism for everything
- [ ] Sound on error (non-zero exit code) — primary user need; the reason users install this
- [ ] Sound on success — symmetry; feels incomplete without it
- [ ] Default bundled sounds — required for any out-of-box experience; no setup = instant gratification
- [ ] Configurable time threshold — prevents sound on every `ls`; without this, users uninstall immediately
- [ ] Command blacklist — same reason; `man`/`vim`/`watch` must not trigger
- [ ] Global enable/disable toggle — required for SSH sessions and CI; missing this causes breakage in the wild
- [ ] Silent/headless auto-detection — same reason; SSH audio is a known anti-pattern
- [ ] ASCII art reactions on error/success — this is the core fun differentiator; without it, Better Shell is just zsh-notify
- [ ] Exit code indicator in prompt — table stakes for the prompt theme; trivial complexity, high polish
- [ ] Source-based install — the only install path

### Add After Validation (v1.x)

Features to add once core is working and the trigger mechanism is proven.

- [ ] Animated spinners — valuable but requires both hooks working reliably; add when hook system is stable
- [ ] Custom sound file support — user request trigger; add when users report wanting their own sounds
- [ ] YAML/TOML config file — when trigger rules complexity justifies structured config over env vars
- [ ] CLI for trigger setup — companion to config file; add together
- [ ] Custom trigger rules (per-command patterns) — the power-user differentiator; requires config file first
- [ ] Sound theming / packs — trivial once bundled sounds exist; add as a polish feature
- [ ] Art variant randomization — depends on having multiple ASCII art pieces; add with art library

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Stderr detection trigger — highest complexity; requires companion binary or process substitution; validates only if users report needing warnings to trigger feedback
- [ ] Per-project config override — direnv-style; useful for polyglot developers; deferred because global config satisfies the majority
- [ ] Dynamic prompt theme full persona — animated or highly complex prompt theming; deferred until base prompt segment is proven

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Exit code detection (precmd hook) | HIGH | LOW | P1 |
| Sound on error | HIGH | LOW | P1 |
| Sound on success | HIGH | LOW | P1 |
| Default bundled sounds | HIGH | LOW | P1 |
| Configurable time threshold | HIGH | LOW | P1 |
| Command blacklist | HIGH | LOW | P1 |
| Global enable/disable toggle | HIGH | LOW | P1 |
| Silent/headless auto-detection | HIGH | MEDIUM | P1 |
| ASCII art reactions | HIGH | MEDIUM | P1 |
| Exit code indicator in prompt | MEDIUM | LOW | P1 |
| Source-based install | HIGH | LOW | P1 |
| Animated spinners | HIGH | MEDIUM | P2 |
| Custom sound file support | MEDIUM | LOW | P2 |
| YAML/TOML config file | MEDIUM | MEDIUM | P2 |
| CLI for trigger setup | MEDIUM | MEDIUM | P2 |
| Custom trigger rules | HIGH | HIGH | P2 |
| Sound theming / packs | MEDIUM | LOW | P2 |
| Art variant randomization | MEDIUM | LOW | P2 |
| Stderr detection trigger | MEDIUM | HIGH | P3 |
| Per-project config override | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

---

## Competitor Feature Analysis

| Feature | zsh-notify | zsh-auto-notify | oh-my-posh / powerlevel10k | Better Shell (our approach) |
|---------|------------|-----------------|-----------------------------|------------------------------|
| Error sound | Yes (macOS only natively) | No | No | Yes (cross-platform) |
| Success sound | Yes | No | No | Yes |
| Desktop OS notification | Yes (primary feature) | Yes (primary feature) | No | No (deliberately) |
| ASCII art reactions | No | No | No | Yes (primary differentiator) |
| Animated spinners | No | No | No | Yes |
| Prompt exit code indicator | No | No | Yes | Yes |
| Custom trigger rules | No | No | No | Yes |
| Config file (YAML/TOML) | No (zstyle / env vars) | No (env vars) | Yes (JSON) | Yes (TOML) |
| CLI for setup | No | No | No | Yes |
| Command blacklist | Yes | Yes | N/A | Yes |
| Time threshold | Yes (30s default) | Yes (10s default) | N/A | Yes (configurable) |
| SSH/headless detection | Partial (focus check) | No | N/A | Yes |
| POSIX / bash compat | No (zsh only) | No (zsh only) | Cross-shell (binary) | Yes (POSIX + bash-preexec) |
| Install method | oh-my-zsh / antigen | oh-my-zsh / antigen | Binary install | Source-based (single line) |

**Key gap identified:** No existing plugin combines in-terminal audio + in-terminal visuals (art + spinners) + custom event trigger rules in a single POSIX-compatible package. The market has notification-focused tools (zsh-notify, auto-notify) and prompt-focused tools (oh-my-posh, p10k) but nothing that makes the shell feel *reactive and expressive* end-to-end.

---

## Sources

- [zsh-notify (marzocchi)](https://github.com/marzocchi/zsh-notify) — feature set, configuration options, platform support
- [zsh-auto-notify (MichaelAquilina)](https://github.com/MichaelAquilina/zsh-auto-notify) — blacklist/whitelist patterns, threshold design
- [bash-preexec (rcaloras)](https://github.com/rcaloras/bash-preexec) — hook compatibility for bash
- [oh-my-posh (JanDeDobbeleer)](https://github.com/JanDeDobbeleer/oh-my-posh) — prompt segment design, cross-shell architecture
- [powerlevel10k (romkatv)](https://github.com/romkatv/powerlevel10k) — prompt performance expectations, feature set
- [awesome-shell (alebcay)](https://github.com/alebcay/awesome-shell) — ecosystem overview, notification tools
- [awesome-zsh-plugins (unixorn)](https://github.com/unixorn/awesome-zsh-plugins) — plugin ecosystem landscape
- [revolver — ZSH spinner](https://github.com/molovo/revolver) — spinner implementation patterns
- [bash-spinner (tlatsas)](https://github.com/tlatsas/bash-spinner) — POSIX spinner technique
- [direnv](https://direnv.net/) — per-directory config pattern reference
- [Sound effects for Claude Code hooks](https://alexop.dev/posts/how-i-added-sound-effects-to-claude-code-with-hooks/) — real-world cross-platform audio (afplay/aplay/paplay) implementation and async (`&`) pattern
- [Terminal Joy: cowsay, figlet, lolcat](https://medium.com/@Smyekh/terminal-joy-how-fortune-cowsay-figlet-and-lolcat-add-life-to-my-developer-workflow-b5b1c6b10474) — fun terminal tool landscape
- [ZSH startup performance](https://alextheobold.com/posts/profiling_zsh/) — latency expectations (<10ms perception threshold)
- [Codex CLI bell sound discussion](https://github.com/openai/codex/discussions/1303) — real-world audio-over-SSH annoyance

---
*Feature research for: shell enhancement / fun terminal plugin (audio + visual effects)*
*Researched: 2026-02-26*
