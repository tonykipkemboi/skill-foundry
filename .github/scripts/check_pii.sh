#!/usr/bin/env bash
# check_pii.sh <root-dir>
# Hard gate: real corporate emails and Slack USER ids (not channel ids).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-.}"
. "$(dirname "${BASH_SOURCE[0]}")/policy-config.sh"
EMAIL_ALLOW="^(${PII_EMAIL_ALLOW_LOCALPARTS})@${PII_EMAIL_DOMAIN}$"

scan() { # <regex> <label> <fix>
  # --exclude-dir=tests --exclude-dir=docs skips the template's own test fixtures on a repo-root scan;
  # it is a no-op when ROOT is itself a fixture dir (no nested 'tests' dir).
  # Scope covers reference/script file types too (html, py, js, csv) -- reference and
  # script files can carry real emails that a markdown-only scan never sees.
  grep -RInE "$1" "$ROOT" --exclude-dir=tests --exclude-dir=docs --include='*.md' --include='*.txt' \
       --include='*.json' --include='*.yaml' --include='*.yml' \
       --include='*.html' --include='*.py' --include='*.js' --include='*.csv' 2>/dev/null \
  | while IFS=: read -r file line match; do
      rel="${file#"$ROOT"/}"
      token="$(printf '%s' "$match" | grep -oE "$1" | head -1)"
      # email allowlist
      if [ "$2" = "corporate email" ] && printf '%s' "$token" | grep -Eq "$EMAIL_ALLOW"; then
        continue
      fi
      # Real Slack user IDs contain digits; all-letter tokens are ordinary words that
      # happen to start with U (e.g. UNALLOCATED in code scanned since the .py expansion).
      if [ "$2" = "Slack user ID" ] && ! printf '%s' "$token" | grep -q '[0-9]'; then
        continue
      fi
      emit_finding pii hard "$rel" "$line" "$2: $token" "$3"
    done
}

scan "[A-Za-z0-9._%+-]+@${PII_EMAIL_DOMAIN}" "corporate email" "replace with a placeholder like name@your-domain"
scan '\bU[A-Z0-9]{8,12}\b' "Slack user ID" "remove the user ID or use a config placeholder"
