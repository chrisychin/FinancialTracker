#!/usr/bin/env bash
# Ensure FinancialTracker's Python 3.14 venv exists and matches requirements.txt.
# Idempotent: a no-op (a hash compare) once the venv is current.
# Run by the SessionStart hook in .claude/settings.local.json.
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENV="$PROJECT_DIR/.venv_financial_tracker"
REQS="$PROJECT_DIR/requirements.txt"
STAMP="$VENV/.requirements.sha256"
PY_VENV="$VENV/bin/python"

# Emit SessionStart context for Claude, then exit.
emit() {
  python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.argv[1]}}))' "$1" 2>/dev/null \
    || printf '%s\n' "$1"
  exit 0
}

interpreter_note="Python for this project: $PY_VENV (venv .venv_financial_tracker, 3.14). Run all Python and pip in this repo through it — never bare 'python3' or the venvs in the parent AI_experiments/ directory."

find_py314() {
  for c in python3.14 /opt/homebrew/bin/python3.14 /usr/local/bin/python3.14; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  return 1
}

venv_is_314() {
  [ -x "$PY_VENV" ] && [ "$("$PY_VENV" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)" = "3.14" ]
}

if ! venv_is_314; then
  BASE_PY="$(find_py314)" || emit "SETUP FAILED: python3.14 not found on PATH. Tell the user to install it (brew install python@3.14) before running Python in this repo."
  rm -rf "$VENV"
  "$BASE_PY" -m venv "$VENV" >/dev/null 2>&1 \
    || emit "SETUP FAILED: could not create venv at $VENV. Tell the user."
  "$PY_VENV" -m pip install --upgrade pip -q >/dev/null 2>&1
  rm -f "$STAMP"
fi

# Reinstall only when requirements.txt changed since the last successful install.
[ -f "$REQS" ] || emit "$interpreter_note (No requirements.txt found.)"
WANT="$(shasum -a 256 "$REQS" | cut -d' ' -f1)"
if [ "$(cat "$STAMP" 2>/dev/null || true)" != "$WANT" ]; then
  if OUT="$("$PY_VENV" -m pip install -q -r "$REQS" 2>&1)"; then
    printf '%s' "$WANT" > "$STAMP"
    emit "$interpreter_note (Dependencies were just synced from requirements.txt.)"
  else
    emit "SETUP FAILED: pip install -r requirements.txt failed in $VENV. Report this to the user: ${OUT:-no output}"
  fi
fi

emit "$interpreter_note"
