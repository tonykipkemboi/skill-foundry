---
name: ship-plugin
description: Use when packaging skill files into this department plugin and shipping to GitHub, whether first-time setup or adding/updating skills in an existing plugin. Handles intake, structuring, local checks, commit, and PR.
---

# Ship Plugin

Drive the full pipeline: take loose skill files (SKILL.md, .skill archives, reference
docs), package them into this plugin, run all policy checks locally, and open a PR to
the department's GitHub repo. CI is the authoritative gate, so never push to `main`.

Optimize for **accuracy over speed**: each step below guards against a known failure
mode. Do them all, in order, even when the change looks trivial.

## Two rules before you touch anything (read first)

These apply no matter which assistant runs this (Claude Code, Codex, etc.):

1. **Work on a branch, never on `main`.** Before *any* commit, run
   `git rev-parse --abbrev-ref HEAD`. If it returns `main`, **create a feature branch
   first** (`git checkout -b add-<skill-name>`). Do not commit, edit-then-commit, or push
   on `main` at any point. Every change ships through a branch and a PR.

2. **When you need a decision, ask. Don't guess.** Whenever the next step depends on a
   choice only the user can make, STOP and ask using the **AskUserQuestion** tool (or your
   platform's equivalent interactive prompt) before proceeding. Examples that *require*
   asking: new plugin vs. add-to-existing; the plugin name/slug; which existing plugin to
   target; what the skill should be named if it's ambiguous; whether to include a skill
   that won't work in the target runtime; the semver bump level if unclear. Never assume a
   consequential answer.

   **Make each question easy to answer well.** Use the normal terms (plugin, skill), which
   they know, but with every question briefly say *why you're asking and what the choice
   leads to*, and give an example of a good answer. When you can discover the options
   yourself, present them as concrete choices instead of an open question: for example, run
   `gh repo list YOUR-ORG` or read the existing plugins and offer them as a pick-list
   for "which plugin should this join?". Invite the user to ask back if anything is
   unclear before they answer.

## Step 0: Preflight (audit the repo state before planning anything)

Failure mode this prevents: a plugin rework sitting on an unmerged branch for weeks
while everyone assumes it is live. Never trust the working tree or your memory of the
repo. Audit what is actually merged and deployed:

```bash
gh api user --jq .login          # 0a. right GitHub account? (org 404s usually mean no)
git fetch origin
git log --oneline origin/main -3 # 0b. what is actually on main
gh pr list --state open          # 0c. open PRs that carry prior packaging work?
git branch -a --no-merged origin/main   # 0d. unmerged branches ahead of main?
```

- **0a.** If GitHub API calls or pushes return 404 on repos you know exist, the active
  `gh` account lacks org/SSO access. Switch accounts (`gh auth switch`) before blaming
  the repo.
- **0c/0d.** If an unmerged branch or open PR already contains packaging work (version
  bumps, skill changes), STOP and ask the user whether to build on it, merge it first, or
  supersede it. Do not silently branch from `main` past someone's unshipped work.
- **0e. README drift check:** `ls skills/` and confirm every skill has a row in
  `README.md` and a `dist/` download link. Pre-existing drift means a prior run shipped
  incompletely. Fix it as part of this run and tell the user.

Then decide first-time vs update:
- `grep -l 'DEPT_SLUG\|REPO_NAME' .claude-plugin/plugin.json`: placeholders mean first-time
- `git remote get-url origin`: pointing at the template repo itself (e.g. `skill-foundry`) means first-time
- `ls skills/`: only `example-skill/` means first-time

## Step 1: Intake (inspect before anything enters the repo)

Ask the user where the incoming files are. Gather every `SKILL.md`, `.skill`, and
reference doc. Unzip each `.skill` archive **into a temp directory, not the repo**, and
inspect there first:

1. **Pre-scan for PII and secrets** across ALL file types, including `.html`, `.py`,
   `.js`, `.csv`, scripts, and data files, not just markdown. Failure mode: submitted
   skills can carry an employee's email or chat ID baked in as config. Placeholders that
   pass the gate: `you@your-domain.com`, `USER_ID` (never invent realistic-looking IDs, since
   the scanners can't tell fake from real).
2. **Name-collision guard:** for each incoming skill, check `ls skills/`. If the name
   already exists, this is an **update** (PATCH), not an add (MINOR), and silently
   overwriting may be wrong. Confirm with the user: replace, rename, or skip.
3. **Hardcoded-identity check:** if a skill bakes in any one person's name, email, Slack
   ID, manager, or personal project as its config, flag it to the user. Org-wide skills
   must derive the current user at runtime (look up "who is running me" via the connected
   account / employee search) instead of shipping one person's details. A skill configured
   for one person quietly breaks for everyone else and rots when that person changes roles.

Shell note for agents: quote paths and use **arrays** for lists in loops
(`SKILLS=(a b c)`); a plain space-separated string silently becomes one item under zsh.

## Step 2: Place skills

For each skill, create `skills/<name>/SKILL.md` (plus `references/` and any sibling files)
from the inspected temp copy. Ensure the frontmatter `name` exactly matches the directory
name (lowercase, hyphenated).

If the build later reports `name is required` for a file that visibly has a name, the
frontmatter is probably **invalid YAML**, usually an unquoted `description:` containing
colons. Convert it to a folded block scalar (`description: >`) rather than editing content.

## Step 2b: Update the README (required, every time)

The plugin's `README.md` is the human-facing catalog of what it does. Keep it in sync with
`skills/` on **every** change, not just first-time:

- **Skills added:** add a row to the skills table and a download link under the install
  section for each new skill.
- **Skill updated:** adjust its row/description if its behavior or trigger phrases changed.
- **Skill removed:** delete its row and its download link.

Verify mechanically instead of trusting your memory:

```bash
for s in $(ls skills/); do grep -q "$s" README.md || echo "MISSING FROM README: $s"; done
```

A skill that ships without a README entry is invisible to anyone browsing the repo. Match
the existing table format; do not invent a new layout. (CI also emits an advisory
`readme-sync` finding for any skill missing from the README.)

## Step 3 (first-time only): Make it yours

Replace placeholders in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`:
plugin name, displayName, repo name, descriptions. Delete `skills/example-skill/`.
**README:** the repo starts with the framework's README. Delete it, rename
`README.plugin.md` to `README.md`, and fill in its placeholders (title, skills table,
install links). That skeleton is what Step 2b keeps in sync from then on.

**Naming:** set the plugin `name` (in both `plugin.json` and `marketplace.json`) to a
short lowercase-hyphenated slug with **no `-skills` suffix** (e.g. `acme-general`, not
`acme-general-skills`). The name becomes the command prefix in Claude
(`/acme-general:<skill-name>`). **Also set `displayName`** in both files to the
human-readable title (e.g. `"Acme General"`). Otherwise Claude shows the lowercase slug as
the plugin's visible name. `displayName` is UI-label only; the slug keeps powering
commands and the update key, so the slug must never change after launch.

**CI action:** leave `.github/workflows/skill-policy.yml` using the local action
(`uses: ./.github/actions/lint-skills`). To pull in later template policy changes, run
`bash scripts/sync-from-template.sh` on a branch (it updates the machinery and leaves your
skills/plugin.json/README alone).

## Step 4: Set or bump the plugin version (required)

The `version` in `.claude-plugin/plugin.json` is **not cosmetic**: Claude Code uses it
as the cache key that decides whether members receive an update. If you don't change it,
clicking **Update** in Claude delivers nothing. Always set or bump it, using semver:

- **First-time:** leave it at `1.0.0`.
- **Update, new skill(s) added:** bump **MINOR** (e.g. `1.0.0 -> 1.1.0`).
- **Update, fix to an existing skill (or label/metadata change members should see):**
  bump **PATCH** (e.g. `1.1.0 -> 1.1.1`).
- **Breaking change** (renamed/removed skill, behavior users rely on): bump **MAJOR**.

`plugin.json` `version` is authoritative (it wins over the marketplace entry). Add a dated
entry to `CHANGELOG.md`. **Changelog entries state what changed, never why the bump level
was chosen.** A baked-in rationale ("MAJOR because X was removed") goes stale the moment
a decision changes, and then the history lies.

## Step 5: Build and check locally

```bash
bash scripts/build-org-skills.sh         # validates frontmatter, rebuilds dist/
bash .github/scripts/run-checks.sh .      # same checks CI runs
```

Read the JSONL findings. **Fix every hard finding with the user** (secrets, PII, action
pins, frontmatter, workflow permissions). Surface soft suggestions but don't block on them.

**Hard gate: do not chain past it.** `run-checks.sh` exits non-zero when any hard
finding remains. Run it as its own step and check the exit code; **do NOT run the commit,
push, or PR steps until it exits 0.** Re-run after each fix. If a hard finding can't be
fixed (for example a real secret the user must rotate), STOP and report. Never push a
known-bad branch.

## Step 6: Commit on a branch

Never commit on `main`. Use the operator's corporate git identity (follow your org's commit conventions):

```bash
git checkout -b add-<skill-name>
git add -A
git -c user.name="<user>" -c user.email="<you>@your-domain.com" commit -m "<message>"
```

## Step 7: Ship via PR, and close the loop (confirm before outward actions)

**First-time:** create the repo if missing, then push and open a PR:

```bash
gh repo create YOUR-ORG/<repo> --private --source=. --remote=origin --push
gh pr create --fill
```

**Update:** push to the existing repo and open a PR:

```bash
git push -u origin add-<skill-name>
gh pr create --fill
```

**End-state contract.** Failure mode this prevents: a PR merged minutes before the
packager's final commit was pushed, and the stranded commit silently missed `main` for
weeks. So:

- Report the PR URL **and the head commit SHA** (`git rev-parse HEAD`) to the user.
- If you push *anything* after opening the PR, tell the user the new head SHA and say
  explicitly that the earlier state is stale.
- Only when the branch is complete, state: **"final push done, safe to merge."** The
  user should not merge before hearing this.
- After the user merges, verify the outcome: `git fetch && git show origin/main:.claude-plugin/plugin.json | jq .version`
  must show your bump. If it doesn't, a commit was stranded. Find it
  (`git log origin/main..<branch>`) and cherry-pick it onto a fresh PR immediately.

Remind the user of the delivery step: existing plugin -> members click **Update**;
brand-new plugin -> one-time admin **Sync from GitHub** registration first.

## Step 8: Run report (append to the PR description)

Every packaging PR ends with a standard self-assessment block. This is the benchmark that
shows whether the process is getting more accurate over time. Accuracy and completeness
are the metrics that matter; speed is recorded but secondary.

```markdown
## Run report
- Operation: first-time | add | update | label-only
- Skills processed: N (list)
- Intake pre-scan: clean | N issues fixed before placement (what)
- Local gate: exit 0 on attempt N (hard findings fixed: ...)
- README sync verified: yes (mechanical check)
- Version: X -> Y (bump level + why)
- Human-caught misses this run: 0 (target) | list anything the user had to point out
- Post-PR pushes: none | SHAs + why
- Incidents / new lessons for the skill: none | describe
```

"Human-caught misses" is the headline number: anything the user had to catch that this
skill should have caught. The target is always 0. If it isn't 0, the miss belongs in the
skill: propose the edit in the same conversation. Compare your report against the
previous packaging PR's report in the repo (or the runlog in
`docs/packaging-runlog.md` of the template) to see the trend.

## Guardrails

- **Never commit or push on `main`.** Check the branch first (rule 1) and branch if needed.
- **Ask, don't assume.** Use AskUserQuestion for any consequential choice (rule 2).
- Creating a repo and opening a PR are outward actions, so confirm with the user first.
- The local check is a preview; CI is the source of truth.
- Never edit the plugin `name` slug after launch; use `displayName` for label changes.
- See `.github/skill-policy.md` for what every check means.
