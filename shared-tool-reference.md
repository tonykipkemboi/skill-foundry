# Shared Tool Reference (optional)

If your skills share a common tool-integration pattern (an MCP server, an automation
platform, an internal gateway), document it once here. The build script can bundle this
file into every skill that mentions the tool, so each packaged skill ships self-contained.

To enable: set `SHARED_REF_KEYWORDS` in `.github/scripts/policy-config.sh` to a
|-separated, case-insensitive keyword list (e.g. `internal-gateway|automation-platform`).
Any skill whose SKILL.md matches a keyword gets this file copied into its package.

Replace this placeholder with your actual integration guide, or delete the file and
leave `SHARED_REF_KEYWORDS` empty to disable the feature.
