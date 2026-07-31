#!/usr/bin/env bash
# policy-config.sh -- the ONE file to edit when adopting this framework.
# Sourced by the policy checks; keeps company-specific values out of the check logic.

# Your corporate email domain, regex-escaped (dots as \.). The PII check hard-blocks
# real employee emails at this domain from shipping inside org-wide skills.
PII_EMAIL_DOMAIN='example\.com'

# Localparts allowed as obvious placeholders at that domain (never flagged).
# 'non-' covers descriptive phrases like "the non-@example.com attendees".
PII_EMAIL_ALLOW_LOCALPARTS='name|you|example|user|someone|non-'

# Shared reference doc auto-bundled into any skill whose SKILL.md mentions one of
# these keywords (case-insensitive, |-separated). Use this for a tool-integration
# guide every relevant skill should carry. Empty keyword list disables the feature.
SHARED_REF_FILE='shared-tool-reference.md'
SHARED_REF_KEYWORDS=''
