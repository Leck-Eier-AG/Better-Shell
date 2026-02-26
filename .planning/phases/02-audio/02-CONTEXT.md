# Phase 2: Audio - Context

**Gathered:** 2026-02-26
**Status:** Ready for planning

<domain>
## Phase Boundary

Non-blocking audio feedback on command error, success, and warning (stderr). Ships 3 sound packs with meme as default. Supports custom sounds, blacklist/whitelist, configurable volume, and intensity scaling. Config and trigger rules (Phase 4) are out of scope — this phase hardcodes sensible defaults and provides basic customization through folder structure and a simple config.

</domain>

<decisions>
## Implementation Decisions

### Sound character & packs
- Default vibe is **full meme sounds** — funny, dramatic, internet culture references
- Error examples: reverbed "Fahhh" for light fails, Plankton moaning "ahhhhh" for heavy fails
- Success sounds: ship both triumphant memes (MLG airhorn, "Let's go") AND chill satisfaction (Minecraft XP ding, Mario coin) — user chooses which style
- **3 bundled packs:** Meme (default), Chill, Retro (8-bit)
- Each pack has error, success, and warning sound variants

### Intensity scaling
- Sounds scale in intensity/drama based on command weight
- User can choose scaling method: **duration-based** (longer command = more dramatic) or **command-type-based** (categorized commands)
- Both methods available, user picks which is active
- Each pack needs multiple intensity tiers (at minimum: light, medium, heavy)

### Trigger logic
- **Time threshold: 500ms default** — commands under 500ms are silent (configurable)
- **Three sound categories:** error (non-zero exit), success (zero exit), warning (zero exit + stderr output)
- Warning is a **distinct sound** — its own meme category, not a softer error
- **Sounds overlap** when commands fire rapidly — no cancellation, maximum chaos
- All audio playback is non-blocking (async, fire and forget)

### Blacklist & whitelist
- **Blacklist defaults:** interactive editors (vim, nvim, nano, emacs, vi), pagers/watchers (man, less, more, watch, top, htop), REPLs/sessions (python, node, irb, psql, mysql, ssh)
- Shell builtins (cd, source, export) NOT blacklisted — threshold handles them
- **Regex matching** for blacklist patterns — "python" catches python3, python3.12 etc.
- **Whitelist supported** — overrides both threshold and blacklist (e.g., "always sound for git push")
- **Changes take effect immediately** in current shell — no re-source needed (hot reload)

### Custom sound workflow
- **Two approaches:** folder drop-in (simple) + config mapping (precise)
- Drop-in: put files in ~/.config/better-shell/sounds/{error,success,warning}/
- Config: specify exact file paths in config for per-event override
- Config overrides folder drop-in when both exist
- **Any audio format** the system player supports — no format filtering
- **User-created packs:** a pack is a folder with error/, success/, warning/ subdirs. Drop in packs directory, switch by name. Shareable with others.
- **Configurable volume** (0-100) applied at playback time

### Cross-platform audio
- Auto-detect available player: afplay (macOS), aplay (ALSA/Linux), paplay (PulseAudio/PipeWire)
- Silent no-op on systems with no audio capability
- Volume control passed to player's native volume flag

### Claude's Discretion
- Exact meme sound selection and sourcing for bundled packs
- Intensity tier boundaries (what duration counts as "light" vs "heavy")
- Stderr detection implementation (capture method)
- Hot reload mechanism for blacklist/whitelist changes
- Internal pack folder structure and manifest format
- How volume maps to each player's native flags

</decisions>

<specifics>
## Specific Ideas

- "Full meme sounds" — the user wants the shell to be genuinely funny, not just functional
- Light fail example: reverbed "Fahhh" meme sound
- Heavy fail example: Plankton moaning "ahhhhh" from SpongeBob
- Success should feel rewarding AND funny — both triumphant and chill options available
- Allow sound overlap for maximum chaos when commands chain rapidly
- User packs should be shareable (zip a folder, give to a friend)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-audio*
*Context gathered: 2026-02-26*
