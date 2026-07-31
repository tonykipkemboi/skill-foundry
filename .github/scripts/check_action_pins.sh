#!/usr/bin/env bash
# check_action_pins.sh <root-dir>
# Hard gate: third-party GitHub Actions must be pinned to a 40-char commit SHA.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-.}"

find "$ROOT" -type d \( -name tests -o -name docs \) -prune -o -type f \( -name '*.yml' -o -name '*.yaml' \) -path '*/.github/workflows/*' -print 2>/dev/null \
| while IFS= read -r wf; do
    rel="${wf#"$ROOT"/}"
    grep -nE '^\s*-?\s*uses:' "$wf" | while IFS=: read -r line rest; do
      ref="$(printf '%s' "$rest" | sed -E 's/.*uses:[[:space:]]*//; s/[[:space:]]*(#.*)?$//' | tr -d '"'\''')"
      case "$ref" in
        ./*) continue ;;                            # local action ref, allowed
      esac
      pin="${ref##*@}"
      if ! printf '%s' "$pin" | grep -Eq '^[0-9a-f]{40}$'; then
        emit_finding action-pin hard "$rel" "$line" "$ref" "pin to a full 40-char commit SHA"
      fi
    done
  done
