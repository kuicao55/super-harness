#!/usr/bin/env bash
# Cross-platform hook launcher for claude-codex-harness hooks
# Usage: run-hook.sh <hook-name>
#
# Dispatches to the appropriate hook script.
# Outputs JSON with hookSpecificOutput.additionalContext for Claude to inject.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_NAME="${1:-}"

if [[ -z "$HOOK_NAME" ]]; then
  echo '{"error": "No hook name provided"}'
  exit 1
fi

HOOK_FILE="${SCRIPT_DIR}/${HOOK_NAME}"

if [[ ! -f "$HOOK_FILE" ]]; then
  echo '{"error": "Hook not found: '"$HOOK_NAME"'"}'
  exit 1
fi

if [[ ! -x "$HOOK_FILE" ]]; then
  chmod +x "$HOOK_FILE"
fi

exec "$HOOK_FILE"
