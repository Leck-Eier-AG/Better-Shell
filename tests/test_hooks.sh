#!/usr/bin/env bash
# tests/test_hooks.sh — Integration tests for Better Shell hook infrastructure.
# Runs TAP-style output; exits 1 if any test fails.
# Usage: bash tests/test_hooks.sh  (or: make test)
#
# Note: We do NOT use 'set -e' because many tests intentionally run commands
# that return non-zero exit codes (false, _bsh_is_interactive checks, etc.).

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

_PASS_COUNT=0
_FAIL_COUNT=0
_TEST_NUM=0

_test_pass() {
  local name="$1"
  (( _TEST_NUM++ )) || true
  (( _PASS_COUNT++ )) || true
  printf 'ok %d - %s\n' "$_TEST_NUM" "$name"
}

_test_fail() {
  local name="$1"
  local reason="${2:-}"
  (( _TEST_NUM++ )) || true
  (( _FAIL_COUNT++ )) || true
  printf 'not ok %d - %s\n' "$_TEST_NUM" "$name"
  [[ -n "$reason" ]] && printf '  # FAILED: %s\n' "$reason"
}

# Run all tests from the project root
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# ---------------------------------------------------------------------------
# Phase A: Test _bsh_is_interactive in isolation
#
# Strategy: source lib/header.sh (sets defaults) then lib/env.sh (defines the
# function; the gate 'return 0' only exits env.sh's scope, not this script,
# so the function IS available after sourcing).
# ---------------------------------------------------------------------------

printf '# Phase A: environment detection\n'

# Test 1 — Idempotency guard: source header.sh twice, second source is a no-op
source lib/header.sh
_FIRST_VERSION="$_BSH_VERSION"
_BSH_VERSION="tampered"          # would be reset if header re-ran
source lib/header.sh             # idempotency guard should short-circuit here
if [[ "$_BSH_VERSION" == "tampered" ]]; then
  _test_pass "Idempotency guard: second source is a no-op"
else
  _test_fail "Idempotency guard: second source is a no-op" \
    "_BSH_VERSION was reset to '$_BSH_VERSION' instead of remaining 'tampered'"
fi
_BSH_VERSION="$_FIRST_VERSION"  # restore

# Test 2 — _bsh_is_interactive defined after sourcing env.sh
# source env.sh — the gate triggers 'return 0' which exits env.sh scope only
source lib/env.sh 2>/dev/null
if declare -f _bsh_is_interactive >/dev/null 2>&1; then
  _test_pass "_bsh_is_interactive is defined after sourcing env.sh"
else
  _test_fail "_bsh_is_interactive is defined after sourcing env.sh" \
    "function not found — env.sh may have errored before defining it"
fi

# Test 3 — Non-interactive detection: test scripts are not interactive ($- lacks 'i')
_bsh_is_interactive
_rc=$?
if [[ $_rc -eq 1 ]]; then
  _test_pass "Non-interactive shell correctly returns 1"
else
  _test_fail "Non-interactive shell correctly returns 1" \
    "_bsh_is_interactive returned $_rc in a test script (should be non-interactive)"
fi

# Test 4 — CI variable: CI=true causes return 1
# Use a subshell so CI variable doesn't leak, and we get an isolated environment.
bash -c '
  source lib/header.sh 2>/dev/null
  source lib/env.sh 2>/dev/null
  CI=true
  _bsh_is_interactive
  exit $?
' 2>/dev/null
_rc=$?
if [[ $_rc -eq 1 ]]; then
  _test_pass "CI=true causes _bsh_is_interactive to return 1"
else
  _test_fail "CI=true causes _bsh_is_interactive to return 1" \
    "_bsh_is_interactive returned $_rc when CI=true"
fi

# Test 5 — GITHUB_ACTIONS variable: return 1
bash -c '
  source lib/header.sh 2>/dev/null
  source lib/env.sh 2>/dev/null
  GITHUB_ACTIONS=true
  _bsh_is_interactive
  exit $?
' 2>/dev/null
_rc=$?
if [[ $_rc -eq 1 ]]; then
  _test_pass "GITHUB_ACTIONS=true causes _bsh_is_interactive to return 1"
else
  _test_fail "GITHUB_ACTIONS=true causes _bsh_is_interactive to return 1" \
    "_bsh_is_interactive returned $_rc when GITHUB_ACTIONS=true"
fi

# Test 6 — SSH_TTY set: return 1 (SSH disabled by default)
bash -c '
  source lib/header.sh 2>/dev/null
  source lib/env.sh 2>/dev/null
  SSH_TTY=/dev/pts/0
  _BSH_SSH_ENABLED=0
  _bsh_is_interactive
  exit $?
' 2>/dev/null
_rc=$?
if [[ $_rc -eq 1 ]]; then
  _test_pass "SSH_TTY set + _BSH_SSH_ENABLED=0 causes return 1"
else
  _test_fail "SSH_TTY set + _BSH_SSH_ENABLED=0 causes return 1" \
    "_bsh_is_interactive returned $_rc (should block SSH by default)"
fi

# ---------------------------------------------------------------------------
# Phase B: Test hooks and compat layer
#
# Strategy: manually pre-set the variables that env.sh's gate would have set,
# then source vendor/bash-preexec.sh, compat.sh and hooks.sh to test hooks.
#
# We source bash-preexec directly (not via compat.sh auto-detection) to ensure
# it is loaded before hook registration. compat.sh will detect it is already
# loaded and skip the re-source.
# ---------------------------------------------------------------------------

printf '# Phase B: shell detection and hook functions\n'

# Pre-set variables (bypassing the env.sh gate for hook testing)
_BSH_ENABLED=1
_BSH_SSH_ENABLED=0
_BSH_SHELL="bash"
_BSH_DIR="$(pwd)"

# Reset idempotency guard so lib files can be sourced in this new context
unset _BSH_LOADED

# Source bash-preexec first (so compat.sh sees it as already loaded)
# Suppress its deferred-install PROMPT_COMMAND modifications from affecting
# this test script by sourcing in a way that still defines the arrays.
source vendor/bash-preexec.sh 2>/dev/null

# Source compat.sh — detects bash, sees bash-preexec already loaded
source lib/compat.sh 2>/dev/null

# Source hooks.sh — defines and registers _bsh_preexec and _bsh_precmd
source lib/hooks.sh 2>/dev/null

# Stub _bsh_audio_trigger so hooks.sh precmd calls don't produce
# "command not found" warnings (audio.sh is not loaded in this test file)
_bsh_audio_trigger() { :; }

# Test 7 — Shell detection: _BSH_SHELL should be "bash" (we pre-set it above,
# and compat.sh should agree since BASH_VERSION is set)
if [[ "${_BSH_SHELL:-}" == "bash" ]]; then
  _test_pass "Shell detection: _BSH_SHELL is 'bash'"
else
  _test_fail "Shell detection: _BSH_SHELL is 'bash'" \
    "_BSH_SHELL='${_BSH_SHELL:-<unset>}' (expected 'bash')"
fi

# Test 8 — Hook functions exist: _bsh_preexec must be defined
if declare -f _bsh_preexec >/dev/null 2>&1; then
  _test_pass "_bsh_preexec is defined as a function"
else
  _test_fail "_bsh_preexec is defined as a function" \
    "function not found after sourcing hooks.sh"
fi

# Test 9 — Hook functions exist: _bsh_precmd must be defined
if declare -f _bsh_precmd >/dev/null 2>&1; then
  _test_pass "_bsh_precmd is defined as a function"
else
  _test_fail "_bsh_precmd is defined as a function" \
    "function not found after sourcing hooks.sh"
fi

# Test 10 — Exit code capture: false (exit code 1) -> _BSH_LAST_EXIT should be 1
# We must not use 'false; _bsh_precmd' because even without set -e, on some bash
# versions the semicolon matters. Instead we run false, save $?, then call precmd
# in the same compound command scope carefully.
false
_bsh_precmd
if [[ "${_BSH_LAST_EXIT:-}" == "1" ]]; then
  _test_pass "Exit code capture: false -> _BSH_LAST_EXIT=1"
else
  _test_fail "Exit code capture: false -> _BSH_LAST_EXIT=1" \
    "_BSH_LAST_EXIT='${_BSH_LAST_EXIT:-<unset>}' (expected '1')"
fi

# Test 11 — Exit code capture: true (exit code 0) -> _BSH_LAST_EXIT should be 0
true
_bsh_precmd
if [[ "${_BSH_LAST_EXIT:-}" == "0" ]]; then
  _test_pass "Exit code capture: true -> _BSH_LAST_EXIT=0"
else
  _test_fail "Exit code capture: true -> _BSH_LAST_EXIT=0" \
    "_BSH_LAST_EXIT='${_BSH_LAST_EXIT:-<unset>}' (expected '0')"
fi

# Test 12 — Preexec records command string
_bsh_preexec "ls -la"
if [[ "${_BSH_LAST_CMD:-}" == "ls -la" ]]; then
  _test_pass "preexec records command string: _BSH_LAST_CMD='ls -la'"
else
  _test_fail "preexec records command string: _BSH_LAST_CMD='ls -la'" \
    "_BSH_LAST_CMD='${_BSH_LAST_CMD:-<unset>}'"
fi

# Test 13 — Duration tracking: simulate a 5-second command
_BSH_CMD_START_TIME=$(( SECONDS - 5 ))
true
_bsh_precmd
if [[ "${_BSH_CMD_DURATION:-}" -ge 4 && "${_BSH_CMD_DURATION:-}" -le 6 ]]; then
  _test_pass "Duration tracking: _BSH_CMD_DURATION ~= 5 (got ${_BSH_CMD_DURATION})"
else
  _test_fail "Duration tracking: _BSH_CMD_DURATION ~= 5" \
    "_BSH_CMD_DURATION='${_BSH_CMD_DURATION:-<unset>}' (expected 4-6)"
fi

# Test 14 — Enabled guard: _BSH_ENABLED=0 prevents _BSH_LAST_CMD from updating
_BSH_ENABLED=0
_BSH_LAST_CMD="old_value"
_bsh_preexec "should_not_record"
if [[ "${_BSH_LAST_CMD:-}" == "old_value" ]]; then
  _test_pass "Enabled guard: disabled plugin does not update _BSH_LAST_CMD"
else
  _test_fail "Enabled guard: disabled plugin does not update _BSH_LAST_CMD" \
    "_BSH_LAST_CMD='${_BSH_LAST_CMD:-<unset>}' (expected 'old_value')"
fi
_BSH_ENABLED=1  # restore

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

printf '\n# Results: %d passed, %d failed out of %d tests\n' \
  "$_PASS_COUNT" "$_FAIL_COUNT" "$_TEST_NUM"

if [[ "$_FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
