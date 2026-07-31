# Contributing

How to add or improve skills in this plugin.

Skills can use any tools your team needs. We do not mandate any specific tool platform.
CI checks skills for security and structure on every PR; see
[.github/skill-policy.md](.github/skill-policy.md) for exactly what runs and how to fix findings.

> **Work on a branch, never `main`.** Every change ships through a feature branch and a
> pull request; that's what runs the checks and gates the merge. The `ship-plugin` skill
> does this for you; if you work by hand, `git checkout -b add-<skill-name>` first.

## Adding a New Skill

### 1. Create your skill

```
skills/<your-skill-name>/
├── SKILL.md              # Required: skill instructions
└── references/           # Optional: large static data
    └── *.md
```

**SKILL.md frontmatter:**
```yaml
---
name: my-skill
description: One sentence describing when Claude should use this skill. Include trigger phrases.
---
```

Rules:
- `name` lowercase, <=64 chars, must match the directory name exactly
- `description` <=1024 chars; this is what activates the skill automatically on Claude.ai
- Body under 500 lines; put large reference data in `references/`
- No PII (real emails, full names, Slack user IDs)

Full rules and how findings are surfaced: [.github/skill-policy.md](.github/skill-policy.md).

### 2. Build the package

```bash
bash scripts/build-org-skills.sh
```

Creates `dist/<skill-name>.skill`.

### 3. Test it

Double-click the `.skill` file in `dist/` to install it directly in Claude Desktop. Try the trigger phrases from your description.

### 4. Submit a PR

```bash
git checkout -b add-<skill-name>
# commit your SKILL.md and the built dist/<skill-name>.skill
git push
```

Open a PR. CI runs the skill policy checks (see [.github/skill-policy.md](.github/skill-policy.md)) and verifies `dist/` is in sync with `skills/`. Findings appear as a single PR comment. A reviewer listed in CODEOWNERS will approve before merge.

### Bump the version

Before you open the PR, bump `version` in `.claude-plugin/plugin.json` (semver) and add a
`CHANGELOG.md` entry. This is required: Claude Code uses the plugin version as the update
cache key, so members only receive your change when the version changes. New skill =
MINOR bump; fix = PATCH; breaking change = MAJOR.

## Writing Guidelines

- **Description field matters most:** this is what tells Claude when to activate the skill
- **Pre-flight check:** if a skill depends on an external tool, verifying connections as Step 0 is recommended (see `shared-tool-reference.md`). This is guidance, not a requirement.
- **Don't hardcode tool prefixes:** if using a tool platform with environment-specific prefixes, prefer generic function names over hardcoded prefixes
- **Graceful degradation:** optional integrations (e.g., a meeting-notes tool, enterprise search) should not break the skill if absent
- **Parallelize** tool calls wherever possible

## Updating from the template

"Use this template" copies files once, so later fixes to the template (build script,
checks, `ship-plugin`, etc.) don't reach your repo automatically. To catch up:

```bash
git checkout -b sync-template
bash scripts/sync-from-template.sh
# review the diff, then commit + open a PR
```

It updates only the shared machinery and never touches your skills, `plugin.json`
(your plugin name + version), `README.md`, or `CHANGELOG.md`.

**If your repo predates this script** (created before it existed), bootstrap once:

```bash
gh repo clone YOUR-ORG/skill-foundry /tmp/sf -- --depth 1
cd <your-repo> && git checkout -b sync-template
TEMPLATE_SRC=/tmp/sf bash /tmp/sf/scripts/sync-from-template.sh
```

## Questions?

Ask in your org's AI-tooling Slack channel, or open an issue in this repo.
