#!/bin/bash
# build-org-skills.sh
# Generates .skill files for Claude.ai organization skills upload.
# A .skill file is a ZIP (folder-as-root) with a .skill extension.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$REPO_ROOT/dist"
SKILLS_DIR="$REPO_ROOT/skills"

# Preflight: required tools must exist BEFORE we touch anything. Missing a tool used to
# produce a misleading failure (and, combined with the early dist wipe, lost dist/).
missing=""
command -v yq  >/dev/null 2>&1 || missing="$missing yq"
command -v zip >/dev/null 2>&1 || missing="$missing zip"
if [ -n "$missing" ]; then
  echo "Cannot build: missing required tool(s):$missing" >&2
  echo "Install them first, then re-run:  brew install$missing" >&2
  exit 1
fi

echo "Building .skill packages..."

# Validate frontmatter BEFORE clearing dist/, so a validation failure never destroys an
# existing dist/. (Previously dist/ was wiped first, then validated -- a failure left the
# user with no dist/ and a confusing error.)
echo "Validating skill frontmatter..."
fm_findings="$("$REPO_ROOT/.github/scripts/validate_frontmatter.sh" "$SKILLS_DIR" || true)"
if [ -n "$fm_findings" ]; then
  echo "$fm_findings" | (command -v jq >/dev/null && jq -r '"  ✗ \(.file): \(.message)"' || cat)
  echo "Frontmatter validation failed. Fix the above before building. (dist/ left untouched.)" >&2
  exit 1
fi
echo "  Frontmatter OK."

# Only now is it safe to clear and rebuild dist/.
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Build a .skill file for each skill directory (skip meta-skills like dist)
SKIP_SKILLS="dist"

for skill_dir in "$SKILLS_DIR"/*/; do
  skill_name="$(basename "$skill_dir")"

  # Skip meta-skills that aren't meant for Claude.ai upload
  if echo "$SKIP_SKILLS" | grep -qw "$skill_name"; then
    echo "  Skipped: $skill_name (meta-skill)"
    continue
  fi

  # Create a temporary staging directory
  staging="$DIST_DIR/.staging/$skill_name"
  mkdir -p "$staging"

  # Copy skill contents
  cp -r "$skill_dir"* "$staging/"

  # Optionally bundle a shared reference doc into skills that mention configured
  # keywords (see .github/scripts/policy-config.sh). Disabled when no keywords set.
  . "$REPO_ROOT/.github/scripts/policy-config.sh"
  if [ -n "${SHARED_REF_KEYWORDS:-}" ] && [ -f "$REPO_ROOT/${SHARED_REF_FILE:-}" ] \
     && grep -qiE "$SHARED_REF_KEYWORDS" "$skill_dir/SKILL.md"; then
    cp "$REPO_ROOT/$SHARED_REF_FILE" "$staging/"
  fi

  # Create .skill file (ZIP with folder-as-root, .skill extension)
  (cd "$DIST_DIR/.staging" && zip -r "$DIST_DIR/$skill_name.skill" "$skill_name/" -x "*.DS_Store")

  echo "  Created: dist/$skill_name.skill"
done

# Clean up staging
rm -rf "$DIST_DIR/.staging"

echo ""
echo "Done! Skill packages ready in dist/"
echo ""
echo "To upload: Claude.ai → Settings → Capabilities → Skills → Upload"
