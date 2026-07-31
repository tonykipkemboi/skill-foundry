# Skill Policy

The single source of truth for what CI checks on every PR. The PR comment links here.

These checks grade skills for **security** (so they don't leak secrets or PII) and
**structure** (so they don't fail in production). They target *accidental* harm for
internal company use. They do NOT restrict which tools a skill uses.

## 🛑 Hard gates (block the merge)

| Check | What triggers it | How to fix |
|-------|------------------|-----------|
| Secrets | API keys, tokens, private keys (gitleaks) | Remove it; rotate if it was real |
| PII | Real corporate-domain email (configured in `policy-config.sh`) or Slack user ID (`U...`) in any scanned file type (md, txt, json, yaml, html, py, js, csv) | Use a placeholder (`you@your-domain`, `USER_ID`) or move to non-committed config |
| Action pinning | A GitHub Action `uses:` ref not pinned to a 40-char SHA | Pin to the commit SHA |
| Workflow permissions | A workflow under `.github/workflows/` has no `permissions:` block | Add a least-privilege block (e.g. `permissions:\n  contents: read`) |
| Frontmatter | Frontmatter not valid YAML; `name` not lowercase/<=64/matching dir, reserved name, or `description` missing/>1024 | For YAML errors: quote or fold the value (`description: >`). Otherwise follow the open standard (agentskills.io) |

## 💡 Suggestions (advisory, do not block)

| Check | What triggers it | Suggestion |
|-------|------------------|-----------|
| Body length | SKILL.md body > 500 lines | Move static content to `references/` |
| Description quality | `description` < 50 chars | Say what it does AND when to use it |
| Listing cap | `description` + `when_to_use` near 1536 chars | Trim to avoid listing truncation |
| Argument hint | `argument-hint` declared but body never uses `$ARGUMENTS` (or vice versa) | Align hint and body |
| Channel ID | A Slack channel ID (`C...`) is committed | Confirm it's intentional, not a test channel |
| README sync | A skill in `skills/` has no mention in `README.md` | Add a row to the skills table and a `dist/` download link |

## Not checked

We do not run prompt-injection, malicious-code, or suspicious-download analysis. Those
target adversarial public marketplaces; our threat model is accidental internal harm.
Skills may use any tools the team needs.

## Where the checks live

The check logic is a composite action in the template repo
(`.github/actions/lint-skills`), invoked by `.github/scripts/run-checks.sh`. Department
repos call it from `.github/workflows/skill-policy.yml`. Running `run-checks.sh` locally
gives the same result CI produces (the `ship-plugin` skill does this before pushing).
