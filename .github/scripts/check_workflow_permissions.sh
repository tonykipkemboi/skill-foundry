#!/usr/bin/env bash
# check_workflow_permissions.sh <root-dir>
# Hard gate: every GitHub Actions workflow must set an explicit permissions block so the
# GITHUB_TOKEN follows least privilege. Mirrors CodeQL's actions/missing-workflow-permissions.
# A top-level `permissions:` covers all jobs; we flag a workflow that has none at all.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ROOT="${1:-.}"

find "$ROOT" -type d \( -name tests -o -name docs \) -prune -o -type f \( -name '*.yml' -o -name '*.yaml' \) -path '*/.github/workflows/*' -print 2>/dev/null \
| while IFS= read -r wf; do
    rel="${wf#"$ROOT"/}"
    if ! grep -Eq '^[[:space:]]*permissions:' "$wf"; then
      emit_finding workflow-permissions hard "$rel" 1 \
        "workflow has no permissions block" \
        "add a least-privilege 'permissions:' block (e.g. 'permissions:\\n  contents: read') near the top of the workflow"
    fi
  done
