#!/usr/bin/env bash
# run-tests.sh -- runs run-checks.sh against each fixture and asserts the
# expected findings appear (subset match on check+severity+message-substring),
# and that clean-skill yields zero findings.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO/.github/scripts"
FIX="$REPO/tests/fixtures"
EXP="$REPO/tests/expected"
fails=0

for dir in "$FIX"/*/; do
  name="$(basename "$dir")"
  expfile="$EXP/$name.jsonl"
  actual="$(bash "$SCRIPTS/run-checks.sh" "$dir" 2>/dev/null || true)"
  rm -f "$dir/.skill-findings.jsonl"

  if [ "$name" = "clean-skill" ]; then
    # tolerate the gitleaks-missing soft notice; fail on anything else
    extra="$(printf '%s\n' "$actual" | grep -v '"message":"gitleaks not installed' | grep -c '"check"' || true)"
    if [ "$extra" -ne 0 ]; then
      echo "FAIL: clean-skill produced findings:"; printf '%s\n' "$actual"; fails=$((fails+1))
    else echo "PASS: clean-skill"; fi
    continue
  fi

  if [ ! -f "$expfile" ]; then echo "SKIP: $name (no expected file)"; continue; fi

  ok=1
  while IFS= read -r exp; do
    [ -z "$exp" ] && continue
    c="$(printf '%s' "$exp" | jq -r '.check')"
    s="$(printf '%s' "$exp" | jq -r '.severity')"
    m="$(printf '%s' "$exp" | jq -r '.message')"
    if ! printf '%s\n' "$actual" | jq -ec --arg c "$c" --arg s "$s" --arg m "$m" \
         'select(.check==$c and .severity==$s and (.message|contains($m)))' >/dev/null 2>&1; then
      echo "FAIL: $name missing expected [$c/$s ~ '$m']"; ok=0
    fi
  done < "$expfile"
  if [ "$ok" -eq 1 ]; then echo "PASS: $name"; else printf 'actual:\n%s\n' "$actual"; fails=$((fails+1)); fi
done

# --- Secret checks: fixtures are generated at runtime so NO secret-format string is
# --- ever committed. This keeps org secret scanners (GitHub push protection etc.)
# --- and gitleaks-on-repo clean, while still exercising the secret check. Tokens are
# --- assembled from pieces so the contiguous pattern never appears in this file either.
if command -v gitleaks >/dev/null 2>&1; then
  gen="$(mktemp -d)"
  ghp="ghp_$(printf '%s' 'A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8')"   # 36-char body
  akia="AKIA$(printf '%s' 'Z7XPLW3RT5QN2YBD')"                      # 16-char body

  mkdir -p "$gen/secret-github-pat"
  printf -- '---\nname: secret-github-pat\ndescription: Runtime fixture verifying GitHub PAT detection by the secret check.\n---\n# Body\ntoken = %s\n' "$ghp" > "$gen/secret-github-pat/SKILL.md"

  mkdir -p "$gen/secret-aws-key"
  printf -- '---\nname: secret-aws-key\ndescription: Runtime fixture verifying AWS access key detection by the secret check.\n---\n# Body\naws_access_key_id = %s\n' "$akia" > "$gen/secret-aws-key/SKILL.md"

  mkdir -p "$gen/stray/evil"
  printf -- '---\nname: evil\ndescription: Runtime fixture verifying secrets inside a .skill archive are unpacked and caught.\n---\n# Body\ntoken = %s\n' "$ghp" > "$gen/stray/evil/SKILL.md"
  ( cd "$gen/stray" && zip -r evil.skill evil >/dev/null && rm -rf evil )

  assert_secret() { # <dir> <label>
    local out; out="$(bash "$SCRIPTS/run-checks.sh" "$1" 2>/dev/null || true)"
    rm -f "$1/.skill-findings.jsonl"
    if printf '%s\n' "$out" | jq -ec 'select(.check=="secrets" and .severity=="hard")' >/dev/null 2>&1; then
      echo "PASS: $2"
    else
      echo "FAIL: $2 (no secrets/hard finding)"; printf '%s\n' "$out"; fails=$((fails+1))
    fi
  }
  assert_secret "$gen/secret-github-pat" "secret-github-pat (runtime)"
  assert_secret "$gen/secret-aws-key" "secret-aws-key (runtime)"
  assert_secret "$gen/stray" "stray-skill-archive (runtime)"
  rm -rf "$gen"
else
  echo "SKIP: secret tests (gitleaks not installed; CI runs them)"
fi

# --- Gitignore-awareness: a gitignored file with PII must NOT be flagged (it is never
# --- committed, so CI never sees it). Run in a throwaway git repo.
gi="$(mktemp -d)"
( cd "$gi" && git init -q && git config user.email t@example.com && git config user.name t )
printf 'settings.local.json\n' > "$gi/.gitignore"
printf '{"email":"real.person@example.com"}\n' > "$gi/settings.local.json"   # gitignored
mkdir -p "$gi/skills/clean"
printf -- '---\nname: clean\ndescription: Use when a tracked skill is clean and the gitignored file must be ignored by the scan.\n---\n# Body\nok\n' > "$gi/skills/clean/SKILL.md"
gi_out="$(bash "$SCRIPTS/run-checks.sh" "$gi" 2>/dev/null || true)"
rm -f "$gi/.skill-findings.jsonl"
if printf '%s\n' "$gi_out" | grep -q 'settings.local.json'; then
  echo "FAIL: gitignore-awareness (flagged a gitignored file)"; printf '%s\n' "$gi_out"; fails=$((fails+1))
else
  echo "PASS: gitignore-awareness (gitignored file not flagged)"
fi
rm -rf "$gi"

# --- Dedupe: a finding present in BOTH the source tree and a committed .skill archive
# --- of the same skill must be reported once, not twice (the unpack scan previously
# --- double-reported every finding as skills/x/... and x/x/...).
dd="$(mktemp -d)"
mkdir -p "$dd/skills/dupe" "$dd/dist"
printf -- '---\nname: dupe\ndescription: Runtime fixture verifying that identical findings from the source tree and its packaged archive are deduplicated.\n---\n# Body\nchannel C0AA11BB22C mention\n' > "$dd/skills/dupe/SKILL.md"
( cd "$dd/skills" && zip -r -q "$dd/dist/dupe.skill" dupe )
dd_out="$(bash "$SCRIPTS/run-checks.sh" "$dd" 2>/dev/null || true)"
rm -f "$dd/.skill-findings.jsonl"
dd_count="$(printf '%s\n' "$dd_out" | grep -c 'C0AA11BB22C' || true)"
if [ "$dd_count" -eq 1 ]; then
  echo "PASS: dedupe (source+archive finding reported once)"
else
  echo "FAIL: dedupe (expected 1 finding for C0AA11BB22C, got $dd_count)"; printf '%s\n' "$dd_out"; fails=$((fails+1))
fi
rm -rf "$dd"

# --- Build script safety: the build must NOT delete dist/ before
# --- it validates, and a missing required tool (yq) must fail with a clear message
# --- instead of a misleading one. Run the real build script inside a throwaway repo.
bsf="$(mktemp -d)"
mkdir -p "$bsf/scripts" "$bsf/.github/scripts" "$bsf/dist"
cp "$REPO/scripts/build-org-skills.sh" "$bsf/scripts/"
cp "$REPO"/.github/scripts/*.sh "$bsf/.github/scripts/"

# Test A: a validation failure must leave dist/ intact (validate before rm -rf dist).
mkdir -p "$bsf/skills/badskill"
printf -- '---\nname: wrong-name\ndescription: A skill whose name does not match its directory, used to force a validation failure in the build.\n---\n# Body\nx\n' > "$bsf/skills/badskill/SKILL.md"
echo "keep-me" > "$bsf/dist/sentinel.txt"
bash "$bsf/scripts/build-org-skills.sh" >/dev/null 2>&1; code=$?
if [ "$code" -ne 0 ] && [ -f "$bsf/dist/sentinel.txt" ]; then
  echo "PASS: build preserves dist/ on validation failure"
else
  echo "FAIL: build deleted dist/ on a failed validation (code=$code, sentinel=$([ -f "$bsf/dist/sentinel.txt" ] && echo kept || echo GONE))"; fails=$((fails+1))
fi

# Test B: missing yq must fail with a message that names yq, and not delete dist/.
# Simulate "yq missing" portably: a sandbox bin/ symlinking everything on PATH EXCEPT yq,
# so it doesn't matter which directory yq actually lives in (Homebrew vs /usr/bin).
rm -rf "$bsf/skills/badskill"; mkdir -p "$bsf/skills/good"
printf -- '---\nname: good\ndescription: A valid skill, so the only reason the build fails is the missing yq tool, not the content.\n---\n# Body\nx\n' > "$bsf/skills/good/SKILL.md"
echo "keep-me" > "$bsf/dist/sentinel.txt"
sb="$(mktemp -d)"
oldifs="$IFS"; IFS=:
for d in $PATH; do
  [ -d "$d" ] || continue
  for f in "$d"/*; do
    [ -e "$f" ] || continue
    n="$(basename "$f")"
    [ "$n" = yq ] && continue
    [ -e "$sb/$n" ] || ln -s "$f" "$sb/$n" 2>/dev/null
  done
done
IFS="$oldifs"
out="$(PATH="$sb" /bin/bash "$bsf/scripts/build-org-skills.sh" 2>&1)"; code=$?
rm -rf "$sb"
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -qi 'yq' && [ -f "$bsf/dist/sentinel.txt" ]; then
  echo "PASS: build fails clearly on missing yq without deleting dist/"
else
  echo "FAIL: build did not handle missing yq cleanly (code=$code, names-yq=$(printf '%s' "$out" | grep -qi yq && echo yes || echo no), sentinel=$([ -f "$bsf/dist/sentinel.txt" ] && echo kept || echo GONE))"; fails=$((fails+1))
fi
rm -rf "$bsf"

# --- sync-from-template: must pull machinery (build script, ship-plugin, etc.) but NEVER
# --- touch department-owned files (plugin.json identity, README, skills, changelog).
synctmp="$(mktemp -d)"
# Fake template (source of truth): newer machinery + template-placeholder identity.
mkdir -p "$synctmp/tpl/scripts" "$synctmp/tpl/.claude/skills/ship-plugin" "$synctmp/tpl/.claude-plugin"
echo "NEW-BUILD"  > "$synctmp/tpl/scripts/build-org-skills.sh"
cp "$REPO/scripts/sync-from-template.sh" "$synctmp/tpl/scripts/sync-from-template.sh" 2>/dev/null || echo "placeholder" > "$synctmp/tpl/scripts/sync-from-template.sh"
echo "NEW-SHIP"   > "$synctmp/tpl/.claude/skills/ship-plugin/SKILL.md"
echo '{"name":"DEPT_SLUG"}' > "$synctmp/tpl/.claude-plugin/plugin.json"   # template placeholder -- must NOT overwrite dept's
mkdir -p "$synctmp/tpl/.github/workflows"
echo "skill-policy" > "$synctmp/tpl/.github/workflows/skill-policy.yml"   # dept-relevant -> should sync
echo "test-action"  > "$synctmp/tpl/.github/workflows/test-action.yml"    # template-only -> must NOT sync down
# Fake department repo (target): OLD machinery + REAL identity + a real skill + README.
mkdir -p "$synctmp/dept/scripts" "$synctmp/dept/.claude/skills/ship-plugin" "$synctmp/dept/.claude-plugin" "$synctmp/dept/skills/myskill"
( cd "$synctmp/dept" && git init -q && git config user.email t@e.com && git config user.name t )
echo "OLD-BUILD" > "$synctmp/dept/scripts/build-org-skills.sh"
cp "$REPO/scripts/sync-from-template.sh" "$synctmp/dept/scripts/sync-from-template.sh" 2>/dev/null || echo "placeholder" > "$synctmp/dept/scripts/sync-from-template.sh"
echo "OLD-SHIP"  > "$synctmp/dept/.claude/skills/ship-plugin/SKILL.md"
echo '{"name":"acme-general","version":"1.1.0"}' > "$synctmp/dept/.claude-plugin/plugin.json"   # REAL identity -- must survive
echo "dept readme" > "$synctmp/dept/README.md"
echo "my skill"    > "$synctmp/dept/skills/myskill/SKILL.md"
( cd "$synctmp/dept" && git add -A && git commit -qm init && git checkout -q -b sync-test )
( cd "$synctmp/dept" && TEMPLATE_SRC="$synctmp/tpl" bash scripts/sync-from-template.sh >/dev/null 2>&1 )
sok=1
grep -q NEW-BUILD "$synctmp/dept/scripts/build-org-skills.sh" 2>/dev/null || { echo "FAIL: sync did not update build script"; sok=0; }
grep -q NEW-SHIP "$synctmp/dept/.claude/skills/ship-plugin/SKILL.md" 2>/dev/null || { echo "FAIL: sync did not update ship-plugin"; sok=0; }
grep -q acme-general "$synctmp/dept/.claude-plugin/plugin.json" 2>/dev/null || { echo "FAIL: sync clobbered plugin.json identity"; sok=0; }
grep -q "dept readme" "$synctmp/dept/README.md" 2>/dev/null || { echo "FAIL: sync clobbered README"; sok=0; }
grep -q "my skill" "$synctmp/dept/skills/myskill/SKILL.md" 2>/dev/null || { echo "FAIL: sync clobbered a skill"; sok=0; }
[ -f "$synctmp/dept/.github/workflows/skill-policy.yml" ] || { echo "FAIL: sync did not bring skill-policy.yml"; sok=0; }
[ -f "$synctmp/dept/.github/workflows/test-action.yml" ] && { echo "FAIL: sync brought template-only test-action.yml into the dept repo"; sok=0; }
[ "$sok" -eq 1 ] && echo "PASS: sync-from-template updates machinery, preserves dept content, excludes test-action.yml" || fails=$((fails+1))
rm -rf "$synctmp"

echo "----"
[ "$fails" -eq 0 ] && { echo "All fixture tests passed."; exit 0; } || { echo "$fails fixture test(s) failed."; exit 1; }
