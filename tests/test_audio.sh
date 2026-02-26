#!/usr/bin/env bash
# tests/test_audio.sh — Integration tests for Better Shell audio subsystem.
# Runs TAP-style output; exits 1 if any test fails.
# Usage: bash tests/test_audio.sh  (or: make test)
#
# Note: We do NOT use 'set -e' because many tests intentionally call functions
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
# Setup: load just the files needed (skip env.sh and compat.sh — they gate
# on interactive shell and would exit early in a non-interactive test run).
# ---------------------------------------------------------------------------

_BSH_DIR="$(mktemp -d)"
_BSH_ENABLED=1
_BSH_SSH_ENABLED=0
_BSH_SHELL="bash"
_BSH_VERSION="0.1.0"
_BSH_LOADED=1   # prevent header.sh idempotency guard from resetting our vars

source lib/header.sh 2>/dev/null || true
source lib/config.sh
source lib/hooks.sh
source lib/audio-player.sh
source lib/audio.sh

# ---------------------------------------------------------------------------
# Phase A: function existence checks
# ---------------------------------------------------------------------------

printf '# Phase A: function existence\n'

# Test 1 — _bsh_detect_audio_player is defined
if declare -f _bsh_detect_audio_player >/dev/null 2>&1; then
  _test_pass "_bsh_detect_audio_player is defined"
else
  _test_fail "_bsh_detect_audio_player is defined" "function not found after sourcing audio-player.sh"
fi

# Test 2 — _bsh_play_sound is defined
if declare -f _bsh_play_sound >/dev/null 2>&1; then
  _test_pass "_bsh_play_sound is defined"
else
  _test_fail "_bsh_play_sound is defined" "function not found after sourcing audio-player.sh"
fi

# Test 3 — _bsh_audio_trigger is defined
if declare -f _bsh_audio_trigger >/dev/null 2>&1; then
  _test_pass "_bsh_audio_trigger is defined"
else
  _test_fail "_bsh_audio_trigger is defined" "function not found after sourcing audio.sh"
fi

# ---------------------------------------------------------------------------
# Phase B: player detection
# ---------------------------------------------------------------------------

printf '# Phase B: player detection\n'

# Test 4 — _BSH_AUDIO_TOOL is set after sourcing (to one of the known players)
_valid_tools="pw-play paplay afplay aplay"
if [[ -n "${_BSH_AUDIO_TOOL:-}" ]] && [[ "$_valid_tools" == *"${_BSH_AUDIO_TOOL}"* ]]; then
  _test_pass "_BSH_AUDIO_TOOL is set to a known player ('${_BSH_AUDIO_TOOL}')"
else
  # On a system with no audio, _BSH_AUDIO_TOOL is empty — that is also valid.
  if [[ -z "${_BSH_AUDIO_TOOL:-}" ]]; then
    _test_pass "_BSH_AUDIO_TOOL is empty (no audio player on this system — silent no-op)"
  else
    _test_fail "_BSH_AUDIO_TOOL is a known player" \
      "_BSH_AUDIO_TOOL='${_BSH_AUDIO_TOOL}' is not in: $_valid_tools"
  fi
fi

# ---------------------------------------------------------------------------
# Phase C: volume normalisation
# ---------------------------------------------------------------------------

printf '# Phase C: volume normalisation\n'

# Test 5 — _bsh_vol_afplay 70 outputs "0.70"
_out="$(_bsh_vol_afplay 70)"
if [[ "$_out" == "0.70" ]]; then
  _test_pass "_bsh_vol_afplay 70 outputs '0.70'"
else
  _test_fail "_bsh_vol_afplay 70 outputs '0.70'" "got: '$_out'"
fi

# Test 6 — _bsh_vol_pw 50 outputs "0.50"
_out="$(_bsh_vol_pw 50)"
if [[ "$_out" == "0.50" ]]; then
  _test_pass "_bsh_vol_pw 50 outputs '0.50'"
else
  _test_fail "_bsh_vol_pw 50 outputs '0.50'" "got: '$_out'"
fi

# Test 7 — _bsh_vol_paplay 100 outputs "65536"
_out="$(_bsh_vol_paplay 100)"
if [[ "$_out" == "65536" ]]; then
  _test_pass "_bsh_vol_paplay 100 outputs '65536'"
else
  _test_fail "_bsh_vol_paplay 100 outputs '65536'" "got: '$_out'"
fi

# Test 8 — _bsh_vol_paplay 0 outputs "0"
_out="$(_bsh_vol_paplay 0)"
if [[ "$_out" == "0" ]]; then
  _test_pass "_bsh_vol_paplay 0 outputs '0'"
else
  _test_fail "_bsh_vol_paplay 0 outputs '0'" "got: '$_out'"
fi

# ---------------------------------------------------------------------------
# Phase D: blacklist and whitelist
# ---------------------------------------------------------------------------

printf '# Phase D: blacklist and whitelist\n'

# Test 9 — blacklist matches vim
_bsh_is_blacklisted "vim"
if [[ $? -eq 0 ]]; then
  _test_pass "_bsh_is_blacklisted 'vim' returns 0 (is blacklisted)"
else
  _test_fail "_bsh_is_blacklisted 'vim' returns 0 (is blacklisted)" "returned non-zero"
fi

# Test 10 — blacklist matches python3 (pattern ^python is a prefix match)
_bsh_is_blacklisted "python3"
if [[ $? -eq 0 ]]; then
  _test_pass "_bsh_is_blacklisted 'python3' returns 0 (prefix '^python' matches)"
else
  _test_fail "_bsh_is_blacklisted 'python3' returns 0 (prefix '^python' matches)" "returned non-zero"
fi

# Test 11 — blacklist does NOT match ls
_bsh_is_blacklisted "ls"
if [[ $? -eq 1 ]]; then
  _test_pass "_bsh_is_blacklisted 'ls' returns 1 (not blacklisted)"
else
  _test_fail "_bsh_is_blacklisted 'ls' returns 1 (not blacklisted)" "returned 0"
fi

# Test 12 — blacklist does NOT match git
_bsh_is_blacklisted "git"
if [[ $? -eq 1 ]]; then
  _test_pass "_bsh_is_blacklisted 'git' returns 1 (not blacklisted)"
else
  _test_fail "_bsh_is_blacklisted 'git' returns 1 (not blacklisted)" "returned 0"
fi

# Test 13 — empty whitelist returns false for any command
_BSH_WHITELIST_PATTERNS=()
_bsh_in_whitelist "anything"
if [[ $? -eq 1 ]]; then
  _test_pass "_bsh_in_whitelist 'anything' with empty whitelist returns 1"
else
  _test_fail "_bsh_in_whitelist 'anything' with empty whitelist returns 1" "returned 0"
fi

# ---------------------------------------------------------------------------
# Phase E: intensity calculation
# ---------------------------------------------------------------------------

printf '# Phase E: intensity calculation\n'

# Test 14 — 2 seconds = light
_out="$(_bsh_get_intensity 2)"
if [[ "$_out" == "light" ]]; then
  _test_pass "_bsh_get_intensity 2 outputs 'light'"
else
  _test_fail "_bsh_get_intensity 2 outputs 'light'" "got: '$_out'"
fi

# Test 15 — 15 seconds = medium
_out="$(_bsh_get_intensity 15)"
if [[ "$_out" == "medium" ]]; then
  _test_pass "_bsh_get_intensity 15 outputs 'medium'"
else
  _test_fail "_bsh_get_intensity 15 outputs 'medium'" "got: '$_out'"
fi

# Test 16 — 60 seconds = heavy
_out="$(_bsh_get_intensity 60)"
if [[ "$_out" == "heavy" ]]; then
  _test_pass "_bsh_get_intensity 60 outputs 'heavy'"
else
  _test_fail "_bsh_get_intensity 60 outputs 'heavy'" "got: '$_out'"
fi

# ---------------------------------------------------------------------------
# Phase F: trigger dispatch
# ---------------------------------------------------------------------------

printf '# Phase F: trigger dispatch\n'

# Test 17 — threshold blocks short commands (duration=0, exit=1, blacklist clear)
PLAY_CALLED=0
_bsh_play_sound() { PLAY_CALLED=1; }
_BSH_CMD_DURATION=0
_BSH_LAST_EXIT=1
_BSH_LAST_CMD="ls"
_BSH_AUDIO_TOOL="test"
_BSH_AUDIO_THRESHOLD=1
_bsh_audio_trigger
if [[ "$PLAY_CALLED" -eq 0 ]]; then
  _test_pass "threshold blocks short commands (duration=0 < threshold=1)"
else
  _test_fail "threshold blocks short commands (duration=0 < threshold=1)" "_bsh_play_sound was called"
fi

# Test 18 — blacklist blocks vim even with sufficient duration and failure
PLAY_CALLED=0
_BSH_CMD_DURATION=5
_BSH_LAST_EXIT=1
_BSH_LAST_CMD="vim foo.txt"
_BSH_AUDIO_TOOL="test"
_bsh_audio_trigger
if [[ "$PLAY_CALLED" -eq 0 ]]; then
  _test_pass "blacklist blocks vim (duration=5, exit=1, cmd=vim)"
else
  _test_fail "blacklist blocks vim (duration=5, exit=1, cmd=vim)" "_bsh_play_sound was called"
fi

# Test 19 — error trigger fires for a failing non-blacklisted command
PLAY_CALLED=0
PLAY_FILE=""
_bsh_play_sound() { PLAY_CALLED=1; PLAY_FILE="$1"; }
_BSH_CMD_DURATION=5
_BSH_LAST_EXIT=1
_BSH_LAST_CMD="make build"
_BSH_AUDIO_TOOL="test"
_BSH_LAST_STDERR=""
_bsh_audio_trigger
if [[ "$PLAY_CALLED" -eq 1 ]]; then
  _test_pass "error trigger fires for failing command (make build, exit=1)"
else
  _test_fail "error trigger fires for failing command (make build, exit=1)" "_bsh_play_sound was NOT called"
fi

# ---------------------------------------------------------------------------
# Phase G: sound resolution
# ---------------------------------------------------------------------------

printf '# Phase G: sound resolution\n'

# Test 20 — resolve sound returns empty string when no sounds directory exists
# Use a non-existent _BSH_DIR (we already have a temp one with no sounds/ dir)
_BSH_DIR_SAVED="$_BSH_DIR"
_BSH_DIR="$(mktemp -d)"
_out="$(_bsh_resolve_sound "error" "light")"
rm -rf "$_BSH_DIR"
_BSH_DIR="$_BSH_DIR_SAVED"
if [[ -z "$_out" ]]; then
  _test_pass "_bsh_resolve_sound returns empty string when no sounds directory exists"
else
  _test_fail "_bsh_resolve_sound returns empty string when no sounds directory exists" \
    "got: '$_out'"
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
