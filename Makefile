# Better Shell — Build System
# Source: standard shell project Makefile pattern

DIST   := better-shell.sh
VENDOR := vendor/bash-preexec.sh
LIB    := lib/header.sh lib/env.sh lib/compat.sh lib/hooks.sh lib/toggle.sh lib/config.sh

# Filter to only existing lib files so Plan 02 files (toggle.sh, config.sh) don't break build
EXISTING_LIB := $(wildcard $(LIB))

.PHONY: build clean test

build:
	cat $(VENDOR) $(EXISTING_LIB) > $(DIST)

clean:
	rm -f $(DIST)

test:
	bash tests/test_hooks.sh
