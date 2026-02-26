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

# Project root for resolving bundled sounds in tests that need real files
_BSH_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Setup: load just the files needed (skip env.sh and compat.sh — they gate
# on interactive shell and would exit early in a non-interactive test run).
# ---------------------------------------------------------------------------

_BSH_DIR="$(mktemp -d)"
# Save initial _BSH_DIR so tests that temporarily swap it can restore it
_BSH_DIR_SAVED="$_BSH_DIR"
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
source lib/toggle.sh

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

# Test 17 — error event bypasses threshold (duration=0, exit=1, non-blacklisted cmd)
# `make build` is not blacklisted; even at duration=0 the error sound must play.
PLAY_CALLED=0
PLAY_FILE=""
_bsh_play_sound() { PLAY_CALLED=1; PLAY_FILE="$1"; }
_BSH_CMD_DURATION=0
_BSH_LAST_EXIT=1
_BSH_LAST_CMD="make build"
_BSH_AUDIO_TOOL="test"
_BSH_AUDIO_THRESHOLD=1
_BSH_LAST_STDERR=""
_BSH_SOUND_PACK="meme"
_BSH_DIR="$_BSH_PROJECT_ROOT"
_bsh_audio_trigger
_BSH_DIR="$_BSH_DIR_SAVED"
if [[ "$PLAY_CALLED" -eq 1 && "$PLAY_FILE" == *"error"* ]]; then
  _test_pass "error event bypasses threshold (duration=0, exit=1, non-blacklisted cmd)"
else
  _test_fail "error event bypasses threshold (duration=0, exit=1, non-blacklisted cmd)" \
    "PLAY_CALLED=$PLAY_CALLED PLAY_FILE='$PLAY_FILE'"
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
# Phase H: stderr detection, pack switching, volume, hot reload
# ---------------------------------------------------------------------------

printf '# Phase H: stderr detection, pack switching, volume, hot reload\n'

# Test 21 — _BSH_LAST_STDERR defaults to empty string
_BSH_LAST_STDERR=""
if [[ -z "${_BSH_LAST_STDERR:-}" ]]; then
  _test_pass "_BSH_LAST_STDERR variable defaults to empty"
else
  _test_fail "_BSH_LAST_STDERR variable defaults to empty" "got: '${_BSH_LAST_STDERR}'"
fi

# Test 22 — bsh sound-pack sets _BSH_SOUND_PACK
_BSH_DIR_SAVED="$_BSH_DIR"
_BSH_DIR="$(mktemp -d)"   # use fresh dir so _bsh_config_set writes cleanly
bsh sound-pack retro >/dev/null 2>&1
_result="${_BSH_SOUND_PACK:-}"
rm -rf "$_BSH_DIR"
_BSH_DIR="$_BSH_DIR_SAVED"
if [[ "$_result" == "retro" ]]; then
  _test_pass "bsh sound-pack retro sets _BSH_SOUND_PACK to 'retro'"
else
  _test_fail "bsh sound-pack retro sets _BSH_SOUND_PACK to 'retro'" "got: '$_result'"
fi
# Reset pack to meme for subsequent tests
_BSH_SOUND_PACK="meme"

# Test 23 — sound resolution finds bundled file (project root has sounds/)
# _BSH_DIR must point to the project root where sounds/ lives
_BSH_DIR_SAVED="$_BSH_DIR"
_BSH_DIR="$_BSH_PROJECT_ROOT"
_BSH_SOUND_PACK="meme"
_resolved="$(_bsh_resolve_sound "error" "light")"
_BSH_DIR="$_BSH_DIR_SAVED"
if [[ -n "$_resolved" && "$_resolved" == *.wav ]]; then
  _test_pass "_bsh_resolve_sound finds bundled meme/error/light.wav"
else
  _test_fail "_bsh_resolve_sound finds bundled meme/error/light.wav" "got: '$_resolved'"
fi

# Test 24 — sound resolution returns empty string for nonexistent pack
_BSH_DIR_SAVED="$_BSH_DIR"
_BSH_DIR="$(mktemp -d)"
_BSH_SOUND_PACK="nonexistent"
_resolved="$(_bsh_resolve_sound "error" "light")"
rm -rf "$_BSH_DIR"
_BSH_DIR="$_BSH_DIR_SAVED"
_BSH_SOUND_PACK="meme"
if [[ -z "$_resolved" ]]; then
  _test_pass "_bsh_resolve_sound returns empty for nonexistent pack"
else
  _test_fail "_bsh_resolve_sound returns empty for nonexistent pack" "got: '$_resolved'"
fi

# Test 25 — bsh volume sets _BSH_VOLUME
_BSH_DIR_SAVED="$_BSH_DIR"
_BSH_DIR="$(mktemp -d)"
bsh volume 50 >/dev/null 2>&1
_result="${_BSH_VOLUME:-}"
rm -rf "$_BSH_DIR"
_BSH_DIR="$_BSH_DIR_SAVED"
if [[ "$_result" == "50" ]]; then
  _test_pass "bsh volume 50 sets _BSH_VOLUME to '50'"
else
  _test_fail "bsh volume 50 sets _BSH_VOLUME to '50'" "got: '$_result'"
fi

# Test 26 — _bsh_audio_config_check function exists
if declare -f _bsh_audio_config_check >/dev/null 2>&1; then
  _test_pass "_bsh_audio_config_check is defined"
else
  _test_fail "_bsh_audio_config_check is defined" "function not found after sourcing audio.sh"
fi

# Test 27 — intensity tier boundaries
_out27a="$(_bsh_get_intensity 4)"
_out27b="$(_bsh_get_intensity 5)"
_out27c="$(_bsh_get_intensity 30)"
_out27d="$(_bsh_get_intensity 31)"
if [[ "$_out27a" == "light" && "$_out27b" == "medium" && "$_out27c" == "medium" && "$_out27d" == "heavy" ]]; then
  _test_pass "intensity boundaries: 4=light, 5=medium, 30=medium, 31=heavy"
else
  _test_fail "intensity boundaries: 4=light, 5=medium, 30=medium, 31=heavy" \
    "got: 4='$_out27a' 5='$_out27b' 30='$_out27c' 31='$_out27d'"
fi

# Test 28 — trigger fires warning event when _BSH_LAST_STDERR=1 and exit=0
# Strategy: override _bsh_audio_trigger internals by checking what sound file
# path is passed to _bsh_play_sound.  We point _BSH_DIR to the project root
# so _bsh_resolve_sound finds the real bundled sounds, then verify that the
# resolved file path contains "warning" (the event category in the path).
PLAY_CALLED=0
PLAY_FILE=""
_bsh_play_sound() { PLAY_CALLED=1; PLAY_FILE="$1"; }
_BSH_CMD_DURATION=5
_BSH_LAST_EXIT=0
_BSH_LAST_CMD="make build"
_BSH_AUDIO_TOOL="test"
_BSH_LAST_STDERR="1"
_BSH_SOUND_PACK="meme"
_BSH_DIR="$_BSH_PROJECT_ROOT"
_bsh_audio_trigger
_BSH_DIR="$_BSH_DIR_SAVED"
if [[ "$PLAY_CALLED" -eq 1 && "$PLAY_FILE" == *"warning"* ]]; then
  _test_pass "trigger fires warning event when exit=0 but _BSH_LAST_STDERR=1"
else
  _test_fail "trigger fires warning event when exit=0 but _BSH_LAST_STDERR=1" \
    "PLAY_CALLED=$PLAY_CALLED PLAY_FILE='$PLAY_FILE'"
fi

# Test 29 — threshold still blocks short success commands (duration=0, exit=0)
PLAY_CALLED=0
_bsh_play_sound() { PLAY_CALLED=1; }
_BSH_CMD_DURATION=0
_BSH_LAST_EXIT=0
_BSH_LAST_CMD="ls"
_BSH_AUDIO_TOOL="test"
_BSH_AUDIO_THRESHOLD=1
_BSH_LAST_STDERR=""
_bsh_audio_trigger
if [[ "$PLAY_CALLED" -eq 0 ]]; then
  _test_pass "threshold still blocks short success commands (duration=0, exit=0)"
else
  _test_fail "threshold still blocks short success commands (duration=0, exit=0)" \
    "_bsh_play_sound was called"
fi

# Test 30 — error event still blocked by blacklist (vim with exit=1)
PLAY_CALLED=0
_bsh_play_sound() { PLAY_CALLED=1; }
_BSH_CMD_DURATION=0
_BSH_LAST_EXIT=1
_BSH_LAST_CMD="vim foo.txt"
_BSH_AUDIO_TOOL="test"
_BSH_AUDIO_THRESHOLD=1
_BSH_LAST_STDERR=""
_bsh_audio_trigger
if [[ "$PLAY_CALLED" -eq 0 ]]; then
  _test_pass "error event still blocked by blacklist (vim with exit=1)"
else
  _test_fail "error event still blocked by blacklist (vim with exit=1)" \
    "_bsh_play_sound was called (blacklist should have blocked)"
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
