#!/usr/bin/env bash
# lint_structure.sh <root-dir>
# Soft gates: body length, description quality, listing-cap proximity,
# argument-hint mismatch, Slack channel IDs. All advisory (never block).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
ROOT="${1:-.}"

get_field() { yq --front-matter=extract ".$2 // \"\"" "$1" 2>/dev/null; }

# Slack channel IDs (advisory) -- scan text files (skip the template's test fixtures)
grep -RInE '\bC[A-Z0-9]{8,12}\b' "$ROOT" --exclude-dir=tests --exclude-dir=docs --include='*.md' --include='*.txt' \
     --include='*.json' --include='*.yaml' --include='*.yml' 2>/dev/null \
| while IFS=: read -r file line match; do
    rel="${file#"$ROOT"/}"
    tok="$(printf '%s' "$match" | grep -oE '\bC[A-Z0-9]{8,12}\b' | head -1)"
    # Real Slack channel IDs contain digits; this avoids false positives on
    # all-letter caps words like CONTRIBUTING or CHANGELOG.
    printf '%s' "$tok" | grep -q '[0-9]' || continue
    emit_finding channel-id soft "$rel" "$line" "Slack channel ID: $tok" "confirm this channel is intentional, not a personal test channel"
  done

# README sync (advisory) -- every skill in skills/ should be listed in the README.
# Catches the failure mode where a rework swaps the skill set but ships the old
# README, leaving new skills invisible to anyone browsing the repo. Only meaningful on
# a repo-root scan (fixtures and unpacked archives have no README.md).
if [ -f "$ROOT/README.md" ] && [ -d "$ROOT/skills" ]; then
  for d in "$ROOT"/skills/*/; do
    [ -d "$d" ] || continue
    s="$(basename "$d")"
    grep -q "$s" "$ROOT/README.md" || \
      emit_finding readme-sync soft "README.md" 0 "skill '$s' not listed in README" \
        "add a row to the README skills table and a dist/ download link"
  done
fi

while IFS= read -r skill; do
  rel="${skill#"$ROOT"/}"

  # body length (lines after frontmatter close)
  body_start="$(grep -n '^---$' "$skill" | sed -n '2p' | cut -d: -f1)"
  if [ -n "$body_start" ]; then
    total="$(wc -l < "$skill")"
    body=$(( total - body_start ))
    [ "$body" -gt 500 ] && emit_finding body-length soft "$rel" 0 "body exceeds 500 lines ($body)" "move static content to references/"
  fi

  # description quality
  desc="$(get_field "$skill" description)"
  if [ -n "$desc" ] && [ ${#desc} -lt 50 ]; then
    emit_finding description soft "$rel" 0 "description under 50 chars" "describe what the skill does AND when to use it"
  fi

  # listing-cap proximity (description + when_to_use >= 1400 of 1536)
  wtu="$(get_field "$skill" when_to_use)"
  combined=$(( ${#desc} + ${#wtu} ))
  [ "$combined" -ge 1400 ] && emit_finding listing-cap soft "$rel" 0 "description + when_to_use near 1536 cap ($combined)" "trim to avoid listing truncation"

  # argument-hint <-> body mismatch
  hint="$(get_field "$skill" argument-hint)"
  uses_args="$(grep -cE '\$ARGUMENTS|\$[0-9]' "$skill" || true)"
  if [ -n "$hint" ] && [ "$uses_args" -eq 0 ]; then
    emit_finding argument-hint soft "$rel" 0 "argument-hint declared but body never uses \$ARGUMENTS" "use the argument in the body or remove the hint"
  elif [ -z "$hint" ] && [ "$uses_args" -gt 0 ]; then
    emit_finding argument-hint soft "$rel" 0 "body uses \$ARGUMENTS but no argument-hint declared" "add an argument-hint field"
  fi
done < <(find "$ROOT" -type d \( -name tests -o -name docs \) -prune -o -type f -name SKILL.md -print 2>/dev/null)
