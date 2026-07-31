---
name: example-skill
description: REPLACE with one sentence describing when Claude should use this skill, including trigger phrases like use when the user says X or Y (up to 1024 chars).
argument-hint: "[optional hint shown to user, e.g. topic or meeting name]"
---

# Example Skill Title

REPLACE: Brief intro explaining what this skill does and what the user gets from it.

> **Configuration:** List any required MCP connections or tool integrations here, e.g. "This skill requires the calendar MCP connector. See `shared-tool-reference.md` for setup."

## Quick Reference

- **Sources:** List data sources (e.g. Google Calendar, Gmail, Slack)
- **Output:** Describe what the skill produces

---

## Pre-flight Connection Check (if the skill depends on an external tool)

**Always run first.** Verify connections before doing real work:

```json
{
  "toolkits": ["googlecalendar", "gmail"],
  "session_id": "example-skill"
}
```

| Result | Action |
|--------|--------|
| All connections Active | Proceed to Step 1 |
| Required tool/MCP not available | **Stop.** Tell the user which connector to enable and where. |
| Any connection not active | Show auth URL. Retry once. If still failing, stop and report. |

---

## Workflow

### Step 1: [First Step Name]

REPLACE: Describe what Claude should do in this step. Be specific, since Claude follows instructions literally. If the user passed an argument, it is available as `$ARGUMENTS` (matching the `argument-hint` in the frontmatter); use it here or remove the hint if the skill takes no argument.

### Step 2: [Second Step Name]

REPLACE: Continue with subsequent steps.

### Step 3: Present Output

```markdown
## [Output Title]

### [Section 1]
[Content]

### [Section 2]
[Content]
```

---

## Guidelines

- REPLACE with rules specific to this skill
- Keep responses scannable: use headers and bullet points
- Parallelize tool calls wherever possible
- Always confirm intent before taking actions (sending messages, creating events)
- No speculation; only include information from actual data sources
