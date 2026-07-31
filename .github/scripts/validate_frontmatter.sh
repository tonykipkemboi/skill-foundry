#!/usr/bin/env bash
# validate_frontmatter.sh <root-dir>
# Implements the agentskills.io open standard for SKILL.md frontmatter.
# Rules source: https://agentskills.io/specification  (implemented here, no dependency)
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-.}"
RESERVED="anthropic claude"

# yq is required; without it every field would read as empty and skills would falsely
# look invalid (or, worse, falsely pass). Fail loudly instead of silently.
if ! command -v yq >/dev/null 2>&1; then
  echo "validate_frontmatter.sh: required tool 'yq' not found. Install it: brew install yq" >&2
  exit 3
fi

# yq reads YAML frontmatter; install: https://github.com/mikefarah/yq
get_field() { # <file> <field>
  yq --front-matter=extract ".$2 // \"\"" "$1" 2>/dev/null
}

while IFS= read -r skill; do
  dir="$(basename "$(dirname "$skill")")"
  rel="${skill#"$ROOT"/}"

  # Parse check FIRST. Invalid YAML (usually an unquoted description full of colons)
  # makes every field read as empty -- which used to surface as the misleading
  # "name is required" even though the field was visibly present. Name the real problem.
  if ! yq --front-matter=extract '.' "$skill" >/dev/null 2>&1; then
    yerr="$(yq --front-matter=extract '.' "$skill" 2>&1 >/dev/null | head -1)"
    emit_finding frontmatter hard "$rel" 0 "frontmatter is not valid YAML: ${yerr:-parse error}" \
      "quote or fold the offending value (e.g. 'description: >' for text containing colons)"
    continue
  fi

  name="$(get_field "$skill" name)"
  desc="$(get_field "$skill" description)"
  compat="$(get_field "$skill" compatibility)"

  # name: required
  if [ -z "$name" ]; then
    emit_finding frontmatter hard "$rel" 0 "name is required" "add a 'name:' field"
  else
    [ ${#name} -gt 64 ] && emit_finding frontmatter hard "$rel" 0 "name exceeds 64 chars" "shorten name"
    if ! printf '%s' "$name" | grep -Eq '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
      emit_finding frontmatter hard "$rel" 0 "name must be lowercase [a-z0-9-]" "rename to lowercase-hyphenated"
    fi
    printf '%s' "$name" | grep -q -- '--' && \
      emit_finding frontmatter hard "$rel" 0 "name must not contain '--'" "remove double hyphen"
    [ "$name" != "$dir" ] && \
      emit_finding frontmatter hard "$rel" 0 "name '$name' must match directory '$dir'" "set name: $dir"
    for r in $RESERVED; do
      [ "$name" = "$r" ] && emit_finding frontmatter hard "$rel" 0 "name '$name' is reserved" "choose a different name"
    done
  fi

  # description: required, <=1024
  if [ -z "$desc" ]; then
    emit_finding frontmatter hard "$rel" 0 "description is required" "add a 'description:' field"
  elif [ ${#desc} -gt 1024 ]; then
    emit_finding frontmatter hard "$rel" 0 "description exceeds 1024 chars" "trim to <=1024 chars"
  fi

  # compatibility: optional, <=500
  if [ -n "$compat" ] && [ ${#compat} -gt 500 ]; then
    emit_finding frontmatter hard "$rel" 0 "compatibility exceeds 500 chars" "trim to <=500 chars"
  fi
done < <(find "$ROOT" -type d \( -name tests -o -name docs \) -prune -o -type f -name SKILL.md -print 2>/dev/null)
