# PLUGIN_DISPLAY_NAME

<!-- When creating a plugin repo from this template: DELETE the framework README.md,
     rename this file to README.md, and replace every placeholder. The ship-plugin
     skill walks through this in Step 3. -->

One sentence describing what this plugin does and who it's for.

## Skills

| Skill | Say... | What Claude Does |
|-------|--------|-----------------|
| example-skill | "trigger phrase" | Brief description of output |

## Setup

### Step 1: Connect Claude to your work apps

<!-- Describe any connectors/MCP servers your skills rely on and where users enable
     them (e.g. Settings -> Connectors). Delete this section if none are needed. -->

### Step 2: Install the plugin

**Claude Code:**
```bash
claude plugin marketplace add YOUR-ORG/REPO_NAME
```

**Claude Desktop / Claude.ai:**
1. Download the `.skill` files from `dist/` (links below)
2. Install via Settings -> Capabilities -> Skills

- [example-skill.skill](https://github.com/YOUR-ORG/REPO_NAME/raw/main/dist/example-skill.skill)

## For Maintainers

- Skill sources live in `skills/<name>/SKILL.md`; built packages in `dist/`.
- Run `bash scripts/build-org-skills.sh` before every commit (keeps `dist/` in sync).
- Every PR runs the policy gate (secrets, PII, frontmatter, structure). See
  [.github/skill-policy.md](.github/skill-policy.md).
- To add a skill, see [CONTRIBUTING.md](CONTRIBUTING.md).
- To pull in framework updates: `bash scripts/sync-from-template.sh` on a branch.
