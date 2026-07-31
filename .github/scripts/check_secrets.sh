#!/usr/bin/env bash
# check_secrets.sh <root-dir>
# Hard gate: hardcoded secrets via gitleaks (v8.19+ uses the `dir` subcommand).
# If gitleaks is missing locally, emit a soft notice (CI always has it). Scans the
# given dir as-is (fixtures are scanned on purpose here; the repo-root .gitleaksignore
# only applies when scanning from the repo root).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-.}"

if ! command -v gitleaks >/dev/null 2>&1; then
  emit_finding secrets soft "$ROOT" 0 "gitleaks not installed; secret scan skipped locally" "CI runs gitleaks; install locally with 'brew install gitleaks' for full preview"
  exit 0
fi

report="$(mktemp)"
# `gitleaks dir` scans files on disk (no git history needed for a working tree / fixture).
gitleaks dir "$ROOT" --report-format json --report-path "$report" >/dev/null 2>&1 || true

if [ -s "$report" ] && [ "$(jq 'length' "$report" 2>/dev/null || echo 0)" -gt 0 ]; then
  abs_root="$(cd "$ROOT" 2>/dev/null && pwd)"
  jq -c '.[]' "$report" 2>/dev/null | while IFS= read -r row; do
    file="$(printf '%s' "$row" | jq -r '.File')"
    line="$(printf '%s' "$row" | jq -r '.StartLine')"
    rule="$(printf '%s' "$row" | jq -r '.RuleID')"
    rel="${file#"$abs_root"/}"; rel="${rel#"$ROOT"/}"
    # gitleaks honors only fingerprint-based .gitleaksignore, not path globs, so we
    # skip the template's own test fixtures and docs (example tokens) by path here.
    # No-op when ROOT is a fixture dir (rel is then a bare filename).
    case "$rel" in tests/*|docs/*|*/tests/*|*/docs/*) continue ;; esac
    emit_finding secrets hard "$rel" "$line" "$rule" "remove the secret and rotate it if it was real"
  done
fi
rm -f "$report"
