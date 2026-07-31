#!/usr/bin/env bash
# lib.sh -- shared helpers for skill policy checks.
# Source this from each check script: . "$(dirname "$0")/lib.sh"

# json_escape <string> -> JSON-safe string (no surrounding quotes)
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}

# emit_finding <check> <severity> <file> <line> <message> <fix>
# Prints one JSONL finding object to stdout.
emit_finding() {
  printf '{"check":"%s","severity":"%s","file":"%s","line":%s,"message":"%s","fix":"%s"}\n' \
    "$(json_escape "$1")" "$(json_escape "$2")" "$(json_escape "$3")" \
    "${4:-0}" "$(json_escape "$5")" "$(json_escape "$6")"
}
