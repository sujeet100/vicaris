#!/usr/bin/env bash
#
# browser-login-helper.sh — FALLBACK login helper for browser testing.
#
# Injects a password from the macOS keychain into the currently-focused browser
# field WITHOUT printing it, so the secret never enters the assistant's context
# or the session transcript. The primary mechanism is the browser's
# saved-password autofill; use this only with explicit sign-off.
#
# Configure via env or args (keeps this script free of any project specifics):
#   VICARIS_LOGIN_SERVICE   keychain service name   (or $1)
#   VICARIS_LOGIN_ACCOUNT   keychain account name   (or $2)
#
# One-time setup (run this yourself, not through the assistant):
#   security add-generic-password -s "<service>" -a "<account>" -w
#   # (you will be prompted for the password interactively)
#
# Usage:
#   1. In the browser, click into the password field so it has focus.
#   2. Make the browser the frontmost app.
#   3. VICARIS_LOGIN_SERVICE=... VICARIS_LOGIN_ACCOUNT=... browser-login-helper.sh
#      (or pass service and account as the first two arguments)
#
set -euo pipefail

SERVICE="${1:-${VICARIS_LOGIN_SERVICE:-}}"
ACCOUNT="${2:-${VICARIS_LOGIN_ACCOUNT:-}}"

if [[ -z "$SERVICE" || -z "$ACCOUNT" ]]; then
  echo "set VICARIS_LOGIN_SERVICE and VICARIS_LOGIN_ACCOUNT (or pass service + account as args)" >&2
  exit 2
fi

if ! pw=$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w 2>/dev/null); then
  echo "keychain lookup failed for ${SERVICE}/${ACCOUNT} — run the one-time setup above" >&2
  exit 1
fi

# Pass the secret to AppleScript via the environment (not argv, so it does not
# show up in `ps`) and type it into the focused field.
PW="$pw" osascript -e 'tell application "System Events" to keystroke (system attribute "PW")' >/dev/null 2>&1
unset pw PW

echo "password injected into focused field"
