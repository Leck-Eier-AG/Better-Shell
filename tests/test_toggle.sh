#!/usr/bin/env bash
# tests/test_toggle.sh — Integration tests for Better Shell toggle and config layer.
# Runs TAP-style output; exits 1 if any test fails.
# Usage: bash tests/test_toggle.sh  (or: make test)
#
# Note: We do NOT use 'set -e' because some tests intentionally run commands
# that return non-zero exit codes.

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
# Setup: minimal environment for toggle and config testing
#
# We set up the variables that header.sh would normally provide, then source
# config.sh and toggle.sh directly. We use a temp dir for _BSH_DIR so the
# tests don't touch the user's real config.
# ---------------------------------------------------------------------------

_BSH_DIR="$(mktemp -d)"
_BSH_ENABLED=1
_BSH_SSH_ENABLED=0
_BSH_SHELL="bash"
_BSH_VERSION="0.1.0"

# Source config.sh (defines _bsh_config_load and _bsh_config_set).
# It will call _bsh_config_load at the bottom — since _BSH_DIR/config doesn't
# exist yet, that's a harmless no-op.
source lib/config.sh

# Source toggle.sh (defines bsh() and _bsh_print_status).
source lib/toggle.sh

printf '# Phase A: bsh on/off/status toggle tests\n'

# ---------------------------------------------------------------------------
# Test 1 — bsh off sets _BSH_ENABLED=0
# ---------------------------------------------------------------------------
_BSH_ENABLED=1
bsh off >/dev/null 2>&1
if [[ "$_BSH_ENABLED" == "0" ]]; then
  _test_pass "bsh off: sets _BSH_ENABLED=0"
else
  _test_fail "bsh off: sets _BSH_ENABLED=0" \
    "_BSH_ENABLED='$_BSH_ENABLED' (expected '0')"
fi

# ---------------------------------------------------------------------------
# Test 2 — bsh on sets _BSH_ENABLED=1
# ---------------------------------------------------------------------------
_BSH_ENABLED=0
bsh on >/dev/null 2>&1
if [[ "$_BSH_ENABLED" == "1" ]]; then
  _test_pass "bsh on: sets _BSH_ENABLED=1"
else
  _test_fail "bsh on: sets _BSH_ENABLED=1" \
    "_BSH_ENABLED='$_BSH_ENABLED' (expected '1')"
fi

# ---------------------------------------------------------------------------
# Test 3 — bsh off prints "Better Shell: off"
# ---------------------------------------------------------------------------
_output="$(bsh off 2>/dev/null)"
if [[ "$_output" == "Better Shell: off" ]]; then
  _test_pass "bsh off: prints 'Better Shell: off'"
else
  _test_fail "bsh off: prints 'Better Shell: off'" \
    "got: '$_output'"
fi

# ---------------------------------------------------------------------------
# Test 4 — bsh on prints "Better Shell: on"
# ---------------------------------------------------------------------------
_output="$(bsh on 2>/dev/null)"
if [[ "$_output" == "Better Shell: on" ]]; then
  _test_pass "bsh on: prints 'Better Shell: on'"
else
  _test_fail "bsh on: prints 'Better Shell: on'" \
    "got: '$_output'"
fi

# ---------------------------------------------------------------------------
# Test 5 — bsh status output contains state and shell
# ---------------------------------------------------------------------------
_BSH_ENABLED=1
_BSH_SHELL="bash"
_output="$(bsh status 2>/dev/null)"
_has_state=0
_has_shell=0
[[ "$_output" == *"enabled"* || "$_output" == *"disabled"* ]] && _has_state=1
[[ "$_output" == *"bash"* ]] && _has_shell=1
if [[ "$_has_state" -eq 1 && "$_has_shell" -eq 1 ]]; then
  _test_pass "bsh status: output contains enabled/disabled state and shell name"
else
  _test_fail "bsh status: output contains enabled/disabled state and shell name" \
    "has_state=$_has_state, has_shell=$_has_shell; output: '$_output'"
fi

# ---------------------------------------------------------------------------
# Test 6 — bsh invalid subcommand returns 1 and writes Usage to stderr
# ---------------------------------------------------------------------------
_stderr_output="$(bsh foobar 2>&1 >/dev/null)"
_rc=$?
if [[ "$_rc" -eq 1 && "$_stderr_output" == *"Usage"* ]]; then
  _test_pass "bsh invalid subcommand: returns 1 and stderr contains 'Usage'"
else
  _test_fail "bsh invalid subcommand: returns 1 and stderr contains 'Usage'" \
    "rc=$_rc, stderr='$_stderr_output'"
fi

# ---------------------------------------------------------------------------
# Test 7 — bsh with no arguments returns 1
# ---------------------------------------------------------------------------
bsh >/dev/null 2>&1
_rc=$?
if [[ "$_rc" -eq 1 ]]; then
  _test_pass "bsh no arguments: returns 1"
else
  _test_fail "bsh no arguments: returns 1" \
    "rc=$_rc (expected 1)"
fi

printf '# Phase B: config persistence tests\n'

# ---------------------------------------------------------------------------
# Test 8 — bsh off --persist creates config file with enabled=0
# ---------------------------------------------------------------------------
rm -f "${_BSH_DIR}/config"
bsh off --persist >/dev/null 2>&1
if [[ -f "${_BSH_DIR}/config" ]] && grep -q "^enabled=0$" "${_BSH_DIR}/config"; then
  _test_pass "bsh off --persist: creates config file with enabled=0"
else
  _test_fail "bsh off --persist: creates config file with enabled=0" \
    "file exists: $(test -f "${_BSH_DIR}/config" && echo yes || echo no); contents: $(cat "${_BSH_DIR}/config" 2>/dev/null)"
fi

# ---------------------------------------------------------------------------
# Test 9 — bsh on --persist updates config file to enabled=1, removing enabled=0
# ---------------------------------------------------------------------------
bsh on --persist >/dev/null 2>&1
_has_one=0
_has_zero=0
grep -q "^enabled=1$" "${_BSH_DIR}/config" && _has_one=1
grep -q "^enabled=0$" "${_BSH_DIR}/config" && _has_zero=1
if [[ "$_has_one" -eq 1 && "$_has_zero" -eq 0 ]]; then
  _test_pass "bsh on --persist: config file contains enabled=1 only"
else
  _test_fail "bsh on --persist: config file contains enabled=1 only" \
    "has_one=$_has_one, has_zero=$_has_zero; contents: $(cat "${_BSH_DIR}/config" 2>/dev/null)"
fi

printf '# Phase C: config load tests\n'

# ---------------------------------------------------------------------------
# Test 10 — _bsh_config_load reads enabled=0 and sets _BSH_ENABLED=0
# ---------------------------------------------------------------------------
printf 'enabled=0\n' > "${_BSH_DIR}/config"
_BSH_ENABLED=1
_bsh_config_load
if [[ "$_BSH_ENABLED" == "0" ]]; then
  _test_pass "_bsh_config_load: enabled=0 in config sets _BSH_ENABLED=0"
else
  _test_fail "_bsh_config_load: enabled=0 in config sets _BSH_ENABLED=0" \
    "_BSH_ENABLED='$_BSH_ENABLED' (expected '0')"
fi

# ---------------------------------------------------------------------------
# Test 11 — _bsh_config_load reads ssh_enabled=1 and sets _BSH_SSH_ENABLED=1
# ---------------------------------------------------------------------------
printf 'ssh_enabled=1\n' > "${_BSH_DIR}/config"
_BSH_SSH_ENABLED=0
_bsh_config_load
if [[ "$_BSH_SSH_ENABLED" == "1" ]]; then
  _test_pass "_bsh_config_load: ssh_enabled=1 in config sets _BSH_SSH_ENABLED=1"
else
  _test_fail "_bsh_config_load: ssh_enabled=1 in config sets _BSH_SSH_ENABLED=1" \
    "_BSH_SSH_ENABLED='$_BSH_SSH_ENABLED' (expected '1')"
fi

# ---------------------------------------------------------------------------
# Test 12 — _bsh_config_load handles malformed lines safely
# ---------------------------------------------------------------------------
printf 'bad line!\n=nokey\n\n# comment\nvalid=ok\n' > "${_BSH_DIR}/config"
_BSH_ENABLED=1
_BSH_SSH_ENABLED=0
_bsh_config_load
_rc=$?
# Should not error and should leave variables unchanged (no known key "valid")
if [[ "$_rc" -eq 0 && "$_BSH_ENABLED" == "1" && "$_BSH_SSH_ENABLED" == "0" ]]; then
  _test_pass "_bsh_config_load: malformed lines cause no error and leave variables unchanged"
else
  _test_fail "_bsh_config_load: malformed lines cause no error and leave variables unchanged" \
    "rc=$_rc, _BSH_ENABLED='$_BSH_ENABLED', _BSH_SSH_ENABLED='$_BSH_SSH_ENABLED'"
fi

# ---------------------------------------------------------------------------
# Test 13 — _bsh_config_set does not leave .tmp files behind
# ---------------------------------------------------------------------------
rm -f "${_BSH_DIR}/config"
_bsh_config_set "enabled" "1"
_tmp_files="$(ls "${_BSH_DIR}/"*.tmp.* 2>/dev/null || true)"
if [[ -z "$_tmp_files" ]]; then
  _test_pass "_bsh_config_set: no .tmp files left behind after atomic write"
else
  _test_fail "_bsh_config_set: no .tmp files left behind after atomic write" \
    "found: $_tmp_files"
fi

# ---------------------------------------------------------------------------
# Test 14 — _bsh_config_load: non-existent config returns 0 without error
# ---------------------------------------------------------------------------
rm -f "${_BSH_DIR}/config"
_bsh_config_load
_rc=$?
if [[ "$_rc" -eq 0 ]]; then
  _test_pass "_bsh_config_load: missing config file returns 0 without error"
else
  _test_fail "_bsh_config_load: missing config file returns 0 without error" \
    "rc=$_rc (expected 0)"
fi

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------
rm -rf "$_BSH_DIR"

# ---------------------------------------------------------------------------
# Results summary
# ---------------------------------------------------------------------------

printf '\n# Results: %d passed, %d failed out of %d tests\n' \
  "$_PASS_COUNT" "$_FAIL_COUNT" "$_TEST_NUM"

if [[ "$_FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
