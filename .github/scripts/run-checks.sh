#!/usr/bin/env bash
# run-checks.sh <repo-root>
# Runs every check, writes JSONL findings to <repo-root>/.skill-findings.jsonl,
# prints them to stdout, and exits non-zero iff any hard finding exists.
# Called by BOTH the CI composite action and the ship-plugin skill.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-.}"
OUT="$ROOT/.skill-findings.jsonl"

# Preflight: yq and jq are required for the checks to produce correct results; without
# them checks would silently mis-report. gitleaks degrades gracefully (soft notice), so
# it is not required here.
for t in yq jq; do
  if ! command -v "$t" >/dev/null 2>&1; then
    echo "run-checks: required tool '$t' not found. Install it: brew install $t" >&2
    exit 2
  fi
done

: > "$OUT"

# Defensive: unpack any committed .skill archives into a temp dir and scan them too.
UNPACK="$(mktemp -d)"
bash "$SCRIPT_DIR/unpack_skill_archives.sh" "$ROOT" "$UNPACK"

run_content_checks() { # <target-dir> <out-file>
  bash "$SCRIPT_DIR/check_secrets.sh"        "$1" >> "$2"
  bash "$SCRIPT_DIR/check_pii.sh"            "$1" >> "$2"
  bash "$SCRIPT_DIR/validate_frontmatter.sh" "$1" >> "$2"
  bash "$SCRIPT_DIR/lint_structure.sh"       "$1" >> "$2"
}
run_content_checks "$ROOT" "$OUT"
# The unpacked-archive scan catches issues that exist ONLY inside committed .skill
# archives. When the same skill also exists in the source tree, the same finding would
# be reported twice (skills/x/... and x/x/...) -- drop unpack findings that duplicate a
# source finding (same check+severity+message), keep the ones unique to the archives.
if [ -d "$UNPACK" ]; then
  UOUT="$(mktemp)"
  run_content_checks "$UNPACK" "$UOUT"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    key="$(printf '%s' "$line" | jq -r '[.check,.severity,.message] | join("\u0001")' 2>/dev/null)"
    if ! jq -e --arg k "$key" 'select(([.check,.severity,.message] | join("\u0001")) == $k)' "$OUT" >/dev/null 2>&1; then
      printf '%s\n' "$line" >> "$OUT"
    fi
  done < "$UOUT"
  rm -f "$UOUT"
fi
# workflow checks only apply to the real repo (not unpacked skills)
bash "$SCRIPT_DIR/check_action_pins.sh" "$ROOT" >> "$OUT"
bash "$SCRIPT_DIR/check_workflow_permissions.sh" "$ROOT" >> "$OUT"

rm -rf "$UNPACK"

# Drop findings for gitignored/untracked-but-ignored files (e.g. .claude/settings.local.json,
# which records local permission rules and often contains the operator's own email). Those
# files are never committed, so CI never sees them -- the local scan shouldn't flag them.
if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  filtered="$(mktemp)"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    f="$(printf '%s' "$line" | jq -r '.file' 2>/dev/null)"
    if [ -n "$f" ] && git -C "$ROOT" check-ignore -q -- "$f" 2>/dev/null; then
      continue   # file is gitignored; not part of the repo content CI checks
    fi
    printf '%s\n' "$line" >> "$filtered"
  done < "$OUT"
  mv "$filtered" "$OUT"
fi

cat "$OUT"
# Gate: any hard finding -> exit 1
if grep -q '"severity":"hard"' "$OUT"; then
  exit 1
fi
exit 0
