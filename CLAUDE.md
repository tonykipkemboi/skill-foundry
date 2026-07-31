# Department Plugin

Department plugin repo created from the skill-foundry template. Skills are instruction files (`SKILL.md`) that teach Claude how to perform specific tasks, packaged together as a Claude plugin.

## CRITICAL: Before Every Commit or Push

**Always run the build script before committing.** This keeps `dist/` in sync with `skills/`.

```bash
bash scripts/build-org-skills.sh
git add dist/
```

Never commit changes to `skills/` without also committing the rebuilt `dist/` files.

The build script also validates frontmatter against the open standard and fails on a bad `name`/`description`. CI re-runs the full policy check (see [.github/skill-policy.md](.github/skill-policy.md)) on every PR.

## Skill Format

- Every skill lives in `skills/<name>/SKILL.md` with an optional `references/` folder
- YAML frontmatter required: `name` (lowercase, <=64 chars, must match the directory) and `description` (<=1024 chars). Full rules in [.github/skill-policy.md](.github/skill-policy.md).
- Keep the body under 500 lines. Put large static content in `references/` files
- Never include PII (real emails, full names, Slack user IDs) in skills

## Adding a New Skill

1. Create `skills/<name>/SKILL.md` with frontmatter
2. Add `references/` files if needed
3. Run `bash scripts/build-org-skills.sh`, then verify `dist/<name>.skill` was created
4. Test: upload `.skill` file to Claude Desktop (Settings → Capabilities → Skills)
5. Commit skill source, built `.skill`, and any README changes

## Tools

Skills may use any tools the team needs: MCP connectors, automation platforms, plain prompts, anything. We do not mandate a tool. **If** your org has a shared tool-integration guide, see `shared-tool-reference.md`; the build script can auto-bundle it into skills that mention configured keywords (see `.github/scripts/policy-config.sh`).

## Conventions

- Default timezone: set your team default here
- Parallelize tool calls wherever possible
- Always confirm intent before taking actions (creating events, sending messages)
- No PII in skills meant for org-wide distribution

## Supply Chain Security

Baseline supply-chain policy for all plugin repos. Apply these every time dependencies are added or updated.

### Lockfile & installs
- Always commit `package-lock.json`. Never `.gitignore` it
- Use `npm ci` in CI, not `npm install`
- Run `npm audit --audit-level=high` as a required CI step. Fail the build on high/critical CVEs
- Add `save-exact=true` to `.npmrc` for repos that handle secrets or file I/O

### Adding a new package
- Check before installing: npm download count, GitHub repo age, maintainer count, last publish date
- Run `npx socket` or check via socket.dev before merging any new dependency PR
- Apply the rule: if it's under 50 lines of straightforward code, write it instead of installing it
- Avoid packages with a single maintainer for anything on the critical path

### GitHub Actions
- Pin all third-party actions by full commit SHA, not a tag:
  `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af68 # v4`
- Never use `@main` or `@latest` for external actions
- Scope `GITHUB_TOKEN` permissions explicitly per workflow (`permissions: contents: read`)
- Never bake secrets into workflow env vars. Use GitHub Secrets instead

### GitHub org settings (verify these are on)
- Dependency graph: on
- Dependabot alerts: on
- Dependabot security updates: on (auto-PRs for CVEs)
- Secret scanning + push protection: on

### Minimum viable bar
`npm ci` in CI + `npm audit --audit-level=high` failing the build + Dependabot on + actions pinned by SHA.
