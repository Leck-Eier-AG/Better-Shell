# Better-Shell

Play a random sound when a command errors. Works with **bash** and **zsh**.

## Quick Start

```bash
git clone <repo-url> ~/better-shell
cd ~/better-shell
bash install.sh
```

Or source it directly without installing:

```bash
source /path/to/better-shell.sh
```

## Adding Sounds

Drop `.mp3`, `.wav`, or `.ogg` files into `~/.better-shell/sounds/` (or the bundled `sounds/` directory).

The repo ships with placeholder files — replace them with your own meme sounds.

## Configuration

Set these environment variables **before** sourcing:

| Variable | Default | Description |
|---|---|---|
| `BETTER_SHELL_ENABLED` | `1` | Set to `0` to disable |
| `BETTER_SHELL_SOUNDS_DIR` | — | Custom sounds directory |
| `BETTER_SHELL_VOLUME` | `100` | Volume 0–100 (ffplay, mpv, sox) |

## Supported Audio Players

Auto-detected in order: `paplay`, `aplay`, `ffplay`, `mpv`, `play` (sox).

## Uninstall

1. Remove the `source .../better-shell.sh` line from your `~/.bashrc` or `~/.zshrc`
2. `rm -rf ~/.better-shell`
