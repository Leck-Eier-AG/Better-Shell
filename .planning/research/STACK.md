# Stack Research

**Domain:** POSIX-compatible shell plugin with audio/visual effects and custom triggers
**Researched:** 2026-02-26
**Confidence:** MEDIUM — core shell hook approach is HIGH confidence; binary language choice is MEDIUM; audio layer cross-platform behavior is MEDIUM

---

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| POSIX sh (core hooks) | POSIX.1-2017 | Shell hook layer, entry point sourced by user | The feature surface requires reading `$?`, hooking `precmd`/`preexec`, and writing to stdout — pure POSIX sh handles all of this without depending on any one shell. Using bash or zsh extensions in the hook layer locks out the other shell and violates the project's broadest-user-base requirement. |
| bash-preexec | 0.6.0 (Aug 2025) | `preexec` / `precmd` hooks for bash | Zsh ships `preexec_functions` and `precmd_functions` natively. bash has no equivalent before 5.3. bash-preexec is the de-facto standard used in production by iTerm2, Ghostty, and Bashhub. Its 0.6.0 release added support for the bash 5.3 `$PS0` native mechanism, so it degrades correctly across bash versions. It must be sourced last in `.bashrc`. |
| Rust (companion binary) | stable (1.85+) | Audio playback, spinner rendering, trigger dispatch | The companion binary needs to: (a) play audio without blocking the shell, (b) animate a spinner on a tty, and (c) parse a TOML config file. Pure shell cannot handle (a) at all. A Rust binary compiles to a single static executable (no runtime), starts in <5 ms, and ships `rodio` for audio in the same crate. Go is the alternative but requires a runtime for goroutine audio scheduling; Rust is the 2025 CLI standard for shell tooling (see: `eza`, `zoxide`, `starship`, `bat`). |
| TOML (config format) | TOML 1.0 | Trigger-to-action mapping config file | TOML is simpler than YAML for human editing (no indentation rules), has a formal 1.0 spec, and `serde`/`toml` in Rust support it natively. YAML would require a Go-based parser (`yq`) or a heavier Rust dependency. The PROJECT.md explicitly lists TOML as a config option alongside YAML — recommend committing to TOML only (see "What NOT to Use"). |

### Supporting Libraries (Rust companion binary)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rodio | 0.22.1 | Cross-platform audio playback (WAV, MP3, FLAC, OGG via Symphonia) | Always — it is the standard RustAudio library, uses `cpal` for OS-level audio device access, and spawns its own background thread so playback is non-blocking relative to the shell. |
| clap | 4.5.x | CLI argument parsing for companion binary | Always — derive-macro API keeps the CLI declaration close to the code. The companion binary needs subcommands: `play`, `spin`, `art`, `trigger`. |
| serde | 1.0.x | Serialization / deserialization framework | Always — required to deserialize TOML config into typed Rust structs. |
| toml (crate) | 1.0.3 | TOML parsing on top of serde | Always — the official `toml` crate implements full TOML 1.1 spec. Use `toml::from_str` to deserialize config file into structs. |
| dirs | 5.x | XDG-compliant config/data path resolution | Use to find `$XDG_CONFIG_HOME/better-shell/config.toml` without hardcoding `~/.config`. Avoids the common mistake of using `$HOME` directly. |

### Shell-Side Libraries (sourced in rc file)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bash-preexec | 0.6.0 | `preexec`/`precmd` hooks for bash | Source before the Better Shell plugin only when the running shell is bash. Detect with `[ -n "$BASH_VERSION" ]`. |
| add-zsh-hook (built-in) | zsh native | Hook registration for zsh | Use `add-zsh-hook preexec` and `add-zsh-hook precmd` instead of directly manipulating `preexec_functions`/`precmd_functions` arrays. This is the Zsh Plugin Standard recommendation — it is safe when multiple plugins register hooks. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| bats-core | Shell-layer integration tests | v1.13.0 (Nov 2024). TAP-compliant, widely used, works with bash and zsh. Write tests that source the plugin and assert hook behavior. Do not use ShellSpec — bats is simpler for integration-style tests and has broader CI support. |
| shellcheck | Static analysis for POSIX shell scripts | Run on every `.sh` file in CI. Catches POSIX non-portability (e.g., `[[ ]]`, `local`, `$BASH_SOURCE`) before they reach users. Pin to `v0.10.0` or later. |
| cargo (Rust toolchain) | Build, test, and release the companion binary | Use `cargo build --release` for distribution. Cross-compile with `cross` (Docker-based) for Linux x86_64 + macOS arm64 + macOS x86_64. |
| cargo-dist | Release binary packaging | Generates install scripts and GitHub Release assets. Simplest distribution story for a Rust binary that needs to be downloaded and placed in `$PATH`. |

---

## Installation

```bash
# Shell plugin — no package manager; user sources from rc file
# (The plugin itself is pure POSIX sh + bash-preexec source)

# Rust companion binary
cargo build --release
# Binary lands at: target/release/better-shell

# Runtime system audio dependencies (shell detection script handles fallback chain):
# Linux: aplay (alsa-utils) OR paplay (pulseaudio-utils) OR play (sox)
# macOS: afplay (built-in) — no install needed

# Dev
cargo test
bats test/
```

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Rust companion binary | Go companion binary | If the team has no Rust experience and speed-to-ship outweighs correctness — Go produces a single binary too, but goroutine-based audio scheduling needs more boilerplate and the ecosystem for terminal audio is weaker. |
| rodio (Rust audio) | System audio tool detection (aplay/afplay/sox) | If you want zero install — system tool detection is POSIX-friendly but requires complex fallback logic, no format normalization, and varies by distro. Use as a fallback inside the Rust binary's error path, not as primary. |
| TOML only | YAML + TOML | If user research shows YAML is strongly preferred — but supporting both doubles config parsing surface area and testing burden. Commit to one. |
| bash-preexec | Shopify/hookbook | hookbook is simpler but less battle-tested. bash-preexec is used by iTerm2 and Ghostty at scale. Use hookbook only if you need a lighter dependency with no external sourcing (hookbook is inline-able). |
| bats-core | ShellSpec | ShellSpec supports more shells but its BDD syntax is unfamiliar and CI setup is heavier. bats is sufficient for integration tests on bash and zsh. |
| add-zsh-hook | Direct array manipulation (`preexec_functions+=...`) | Never use direct array manipulation — it is fragile when multiple plugins are loaded and violates the Zsh Plugin Standard. |
| cargo-dist | GitHub Actions manual binary upload | cargo-dist is the 2025 standard for Rust binary distribution. Manual uploads are error-prone and don't generate install scripts. |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| YAML as the config format | Two parsers in Rust (`serde_yaml`) with a history of breaking changes; human authors confuse significant whitespace. TOML is unambiguous and has a finalized 1.0 spec. | TOML only |
| Python / Node.js companion binary | Requires a runtime present on the user's machine — directly violates the "minimize external dependencies" constraint. A Rust or Go static binary has no runtime requirement. | Rust companion binary |
| `[[ ]]` in core hook scripts | bash/zsh extension — not POSIX. `shellcheck` will flag it. Any file that is sourced by the plugin's init script must use `[ ]`. | `[ ]` (POSIX test) |
| Pure shell audio playback (printf beep / $'\a') | The terminal bell character produces a beep on some systems but is disabled on most modern terminal emulators by default. It cannot play WAV/MP3 files, has no volume control, and is not reliable cross-platform. | rodio in the Rust binary |
| `$BASH_SOURCE[0]` for plugin path detection | bash-only — breaks on zsh and any POSIX sh. | Use the Zsh Plugin Standard `${0:A:h}` for zsh and `BASH_SOURCE[0]` guarded by `[ -n "$BASH_VERSION" ]` for bash. Provide a fallback that requires the user to set `BETTER_SHELL_DIR` explicitly for other shells. |
| Oh My Zsh / Prezto as a dependency | Requiring a specific plugin framework locks out users who don't use it. The plugin must be framework-agnostic — source-able directly. | Implement Zsh Plugin Standard hooks (`add-zsh-hook`) natively so the plugin works with any manager or no manager. |
| zinit turbo mode / lazy loading | If the hook file is not sourced synchronously at shell startup, preexec/precmd will not fire for early commands. Turbo/lazy loading breaks real-time hooks. | Document that the plugin must be sourced eagerly, not lazily. |
| bash 5.3 native `$PS0` preexec directly | bash 5.3 was released in late 2024 and is not yet default on macOS (ships bash 3.2 due to GPL). Using 5.3-native hooks without a fallback excludes most macOS users. | bash-preexec 0.6.0 already wraps `$PS0` for 5.3+ and degrades to DEBUG trap for earlier versions. |

---

## Stack Patterns by Variant

**If targeting bash only (simplified scope):**
- Drop Zsh `add-zsh-hook` code path
- bash-preexec alone is sufficient
- Reduces hook layer to ~50 lines of shell

**If targeting zsh only (most common power user case):**
- Drop bash-preexec entirely
- Use native `add-zsh-hook preexec` and `add-zsh-hook precmd`
- Can use zsh-specific `${(%):-%N}` for plugin path detection
- Smaller surface area, simpler testing

**If audio is optional (no Rust binary):**
- Ship a detection script that tries `afplay` → `paplay` → `aplay` → `sox play` in order
- Loses: spinner rendering, typed config parsing, async non-blocking playback
- Gains: zero-install, pure shell

**If distributing via package managers (Homebrew, AUR):**
- The Rust binary can be a formula / PKGBUILD
- Shell hook file installed to `/usr/share/better-shell/better-shell.sh`
- User sources it; binary in `$PATH` automatically

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| bash-preexec 0.6.0 | bash 3.1 – 5.x | Must be sourced last in `.bashrc`. Experimental subshell support requires `__bp_enable_subshells=true`. |
| rodio 0.22.1 | cpal (OS audio) — Linux: ALSA or PulseAudio, macOS: CoreAudio | On Linux, ALSA headers (`libasound2-dev`) are required at compile time if building from source. The distributed binary links statically. |
| toml crate 1.0.3 | serde 1.0.x | TOML 1.1 spec compliant. `toml::Table` is the dynamic deserialization target if config schema is unknown at compile time. |
| clap 4.5.x | Rust stable 1.74+ | Derive macros require `clap = { version = "4", features = ["derive"] }`. |
| bats-core 1.13.0 | bash 3.2+ | `bats-assert` and `bats-support` helper libraries should be installed alongside; they provide `assert_output` and `assert_success`. |
| shellcheck 0.10.x | sh, bash, dash, ksh | Set `# shellcheck shell=sh` at top of files that must be POSIX-only so SC2039 fires on bash extensions. |

---

## Sources

- [bash-preexec GitHub (rcaloras)](https://github.com/rcaloras/bash-preexec) — version 0.6.0 confirmed from releases page; caveats from README (must be sourced last; subshell limitations) — HIGH confidence
- [bash-preexec v0.6.0 release notes](https://github.com/rcaloras/bash-preexec/releases) — $PS0 support for bash 5.3, removal of sed dependency — HIGH confidence
- [Zsh Plugin Standard (wiki.zshell.dev)](https://wiki.zshell.dev/community/zsh_plugin_standard) — `add-zsh-hook` recommendation, `$0` path handling, plugin namespace requirements — HIGH confidence (official)
- [rodio docs.rs 0.22.1](https://docs.rs/rodio/latest/rodio/) — version and features verified — HIGH confidence
- [toml crate docs.rs 1.0.3](https://docs.rs/toml/latest/toml/) — version confirmed — HIGH confidence
- [yq (mikefarah) v4.52.4 releases](https://github.com/mikefarah/yq/releases) — TOML support confirmed; used as basis for rejecting yq as runtime dependency — MEDIUM confidence
- [Shopify/hookbook README](https://github.com/Shopify/hookbook) — cross-shell hook registration; fish support removed — MEDIUM confidence (WebSearch, code review)
- [bats-core v1.13.0 releases](https://github.com/bats-core/bats-core/releases) — version confirmed Nov 2024 — HIGH confidence
- [clap crates.io 4.5.x](https://crates.io/crates/clap) — version confirmed — HIGH confidence
- [Building Great CLIs in 2025: Node.js vs Go vs Rust](https://medium.com/@no-non-sense-guy/building-great-clis-in-2025-node-js-vs-go-vs-rust-e8e4bf7ee10e) — Rust vs Go tradeoffs — LOW confidence (single Medium article; consistent with broader ecosystem pattern)
- WebSearch: `aplay`/`paplay`/`afplay`/`sox play` cross-platform fallback pattern — MEDIUM confidence (multiple sources converge)
- WebSearch: Antidote, zinit lazy loading shell plugin ecosystem 2025 — MEDIUM confidence

---

*Stack research for: Better Shell — POSIX-compatible reactive shell plugin*
*Researched: 2026-02-26*
