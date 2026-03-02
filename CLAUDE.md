# Better-Shell

Shell addon that plays a random sound on command errors. Bash + zsh compatible.

## Structure
- `better-shell.sh` — Main script (source from rc file)
- `install.sh` — Copies sounds + appends source line to rc file
- `sounds/` — Default sound files (.mp3/.wav/.ogg)

## Key Design Decisions
- All functions/vars prefixed with `__better_shell_` to avoid namespace collisions
- Sound plays in background (`&` + `disown`) so it never blocks the shell
- `hook_init` sentinel prevents firing on the initial source
- Double-source guard via `__BETTER_SHELL_LOADED`
