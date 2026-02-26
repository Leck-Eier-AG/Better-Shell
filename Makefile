# Better Shell — Build System
# Source: standard shell project Makefile pattern

DIST   := better-shell.sh
VENDOR := vendor/bash-preexec.sh
# Concatenation order matters:
#   1. vendor/bash-preexec.sh  — preexec hook support for bash
#   2. lib/header.sh           — idempotency guard, _BSH_DIR, defaults
#   3. lib/config.sh           — config load/write (must run before env.sh to override defaults)
#   4. lib/env.sh              — interactive gate (uses _BSH_SSH_ENABLED which config may set)
#   5. lib/compat.sh           — shell detection, hook setup
#   6. lib/hooks.sh            — hook function definitions + registration
#   7. lib/toggle.sh           — bsh() public dispatcher
LIB    := lib/header.sh lib/config.sh lib/env.sh lib/compat.sh lib/hooks.sh lib/audio-player.sh lib/audio.sh lib/toggle.sh

# Filter to only existing lib files (forward-compatible for future plans)
EXISTING_LIB := $(wildcard $(LIB))

PREFIX := $(HOME)/.better-shell

.PHONY: build clean test install

build:
	@printf '# bash-preexec loader — bash only; wrapped so return cannot exit the sourced file\n' > $(DIST)
	@printf '_bsh_load_bash_preexec() {\n' >> $(DIST)
	@cat $(VENDOR) >> $(DIST)
	@printf '\n}\n' >> $(DIST)
	@printf '[ -n "$${BASH_VERSION-}" ] && _bsh_load_bash_preexec\n' >> $(DIST)
	@printf 'unset -f _bsh_load_bash_preexec 2>/dev/null\n\n' >> $(DIST)
	@cat $(EXISTING_LIB) >> $(DIST)

clean:
	rm -f $(DIST)

install: build
	@mkdir -p $(PREFIX)
	@cp $(DIST) $(PREFIX)/better-shell.sh
	@cp -r sounds $(PREFIX)/sounds
	@echo "Installed to $(PREFIX)"

test:
	bash tests/test_hooks.sh && bash tests/test_toggle.sh && bash tests/test_audio.sh
