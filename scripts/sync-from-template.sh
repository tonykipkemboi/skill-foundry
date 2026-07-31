#!/usr/bin/env bash
# sync-from-template.sh [template-ref]
#
# Pull the latest shared "machinery" from YOUR-ORG/skill-foundry into
# this repo, WITHOUT touching anything the department owns. "Use this template" only
# copies files once at creation time, so this is how an existing plugin repo catches up
# with later template fixes (build safety, ship-plugin, checks, etc.).
#
# What it updates (template-owned machinery):
#   scripts/build-org-skills.sh, scripts/sync-from-template.sh, .github/scripts,
#   .github/actions, .github/workflows, .github/skill-policy.md,
#   .claude/skills/ship-plugin, .gitleaks.toml, CLAUDE.md, CONTRIBUTING.md,
#   shared-tool-reference.md
#
# What it NEVER touches (department-owned):
#   skills/, dist/, .claude-plugin/ (your plugin name + version), README.md, CHANGELOG.md,
#   docs/, and anything else not in the list above.
#
# Safety: refuses to run on main, never pushes. It edits files on your current branch;
# you review the diff and open a PR. CI then re-validates.
#
# Set TEMPLATE_SRC=/path/to/a/local/template to sync from a local copy instead of cloning
# (used by the test suite; also handy offline).
set -uo pipefail

TEMPLATE_REPO="YOUR-ORG/skill-foundry"   # <-- set to wherever your org hosts this framework
TEMPLATE_REF="${1:-main}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "Not inside a git repo." >&2; exit 1; }
cd "$REPO_ROOT"

# Safety: never sync straight onto main/master.
branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  echo "You're on '$branch'. Sync edits files for review, so start a branch first:" >&2
  echo "  git checkout -b sync-template && bash scripts/sync-from-template.sh" >&2
  exit 1
fi

# Template-owned machinery (safe to overwrite). Everything else is left alone.
MACHINERY=(
  "scripts/build-org-skills.sh"
  "scripts/sync-from-template.sh"
  ".github/scripts"
  ".github/actions"
  ".github/workflows"
  ".github/skill-policy.md"
  ".claude/skills/ship-plugin"
  ".gitleaks.toml"
  "CLAUDE.md"
  "CONTRIBUTING.md"
  "shared-tool-reference.md"
)

# Resolve the template source: a local dir (TEMPLATE_SRC) or a shallow clone.
cleanup=""
if [ -n "${TEMPLATE_SRC:-}" ]; then
  SRC="$TEMPLATE_SRC"
else
  tmp="$(mktemp -d)"; cleanup="$tmp"
  echo "Fetching $TEMPLATE_REPO@$TEMPLATE_REF ..."
  if ! git clone --quiet --depth 1 --branch "$TEMPLATE_REF" "https://github.com/$TEMPLATE_REPO.git" "$tmp/t" 2>/dev/null; then
    gh repo clone "$TEMPLATE_REPO" "$tmp/t" -- --depth 1 --branch "$TEMPLATE_REF" >/dev/null 2>&1 \
      || { echo "Could not fetch the template (tried git and gh)." >&2; rm -rf "$tmp"; exit 1; }
  fi
  SRC="$tmp/t"
fi

echo "Syncing machinery from the template (your skills, plugin.json, README, CHANGELOG are left untouched):"
for path in "${MACHINERY[@]}"; do
  src="$SRC/$path"
  if [ ! -e "$src" ]; then echo "  - skip (not in template): $path"; continue; fi
  dest="$REPO_ROOT/$path"
  mkdir -p "$(dirname "$dest")"
  if [ -d "$src" ]; then rm -rf "$dest"; cp -R "$src" "$dest"; else cp "$src" "$dest"; fi
  echo "  - synced: $path"
done

# test-action.yml runs the template's OWN fixture suite (tests/run-tests.sh). A department
# repo has no tests/, so it would just fail there. The .github/workflows dir is synced
# wholesale above, so strip this template-only workflow back out of the destination.
if [ -f "$REPO_ROOT/.github/workflows/test-action.yml" ]; then
  rm -f "$REPO_ROOT/.github/workflows/test-action.yml"
  echo "  - skipped (template-only): .github/workflows/test-action.yml"
fi

[ -n "$cleanup" ] && rm -rf "$cleanup"

echo ""
echo "Changes (review before committing):"
git --no-pager diff --stat
echo ""
echo "Next steps:"
echo "  1. Review the diff above. Your skills / plugin.json / README / CHANGELOG were not touched."
echo "  2. Run the checks:  bash scripts/build-org-skills.sh && bash .github/scripts/run-checks.sh ."
echo "  3. Commit on this branch, push, and open a PR. CI re-validates."
