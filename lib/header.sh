# Better Shell — Header
# Idempotency guard, version, and directory setup.
# This file is sourced first in the concatenated better-shell.sh.

# Idempotency guard: no-op if already loaded
[[ -n "${_BSH_LOADED:-}" ]] && return 0
_BSH_LOADED=1

# Plugin directory — users can override by setting _BSH_DIR before sourcing
_BSH_DIR="${_BSH_DIR:-${HOME}/.better-shell}"

# Version
_BSH_VERSION="0.1.0"

# Enable/disable state (default: on)
_BSH_ENABLED=1

# SSH sessions: disabled by default; set _BSH_SSH_ENABLED=1 to enable
_BSH_SSH_ENABLED=0
