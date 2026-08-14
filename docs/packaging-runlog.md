# Packaging Run Log

Benchmark for the `ship-plugin` packaging process. Every packaging PR ends with a
standardized **Run report** (see ship-plugin Step 8); this file holds the metric
definitions and your running baseline so any operator (human or agent) can see
whether the process is getting more accurate over time.

## Metrics (what we optimize, in order)

1. **Human-caught misses.** Anything a person had to point out that the process should
   have caught (forgotten README, wrong display name, stranded commit). **Target: 0.**
   This is the headline number.
2. **Gate correctness.** Local `run-checks.sh` exit 0 must predict CI green. Any
   CI-red-after-local-green is a gate divergence. Target: 0.
3. **Completeness.** No step skipped: README synced (mechanical check), version bumped,
   changelog entry, dist/ rebuilt, end-state verified on `main` after merge.
4. **Post-PR pushes.** Commits pushed after the PR opened. Not bad by itself, but every
   one is a merge-timing risk; each must be announced with its SHA.
5. **Time to PR.** Recorded, but explicitly secondary to the above.

## Your baseline

Append a row per packaging run. Start the table on your first run.

| Run | Repo / version | Human-caught misses | Notes |
|-----|----------------|--------------------:|-------|
| 1 | | | |

## Lessons already encoded in this framework

Each process step and gate check guards against a known failure mode of skill
pipelines. You inherit the guardrails:

- **"Believed shipped, wasn't."** A rework can sit unmerged on a branch while everyone
  assumes it is live; a PR can be merged moments before the packager's final commit is
  pushed, silently stranding it. -> ship-plugin's
  Step 0 preflight audit and Step 7 end-state contract ("final push done, safe to
  merge" + post-merge verification).
- **PII hiding outside markdown.** Submitted skills can carry an employee's email or
  chat ID as config defaults, or bury PII inside HTML/script reference files a
  markdown-only scanner never sees. -> PII scan across md/txt/json/yaml/html/py/js/csv, and the
  intake pre-scan + hardcoded-identity guard in Step 1.
- **Misleading validator errors.** Invalid YAML frontmatter (an unquoted description
  full of colons) surfaces as "name is required" even though the name is visibly
  present. -> the validator now names the real problem ("frontmatter is not valid YAML").
- **Noise trains people to skim.** Findings can get double-reported (source tree +
  packaged archive), and over-eager patterns flag ordinary all-caps words as chat
  user IDs. -> dedupe in run-checks and a digits-required guard on ID patterns.
- **Stale READMEs.** A rework can swap the skill set but ship the old README, leaving
  new skills invisible. -> the readme-sync advisory check + Step 2b's mechanical
  verification command.
- **The slug/label trap.** Plugins ship with their lowercase slug as the visible
  title when `name` does double duty. -> `displayName` is set at creation; the slug
  never changes after launch (it is the command prefix and update cache key).
- **Scanners reject sanitizers, and attach late.** SAST engines flag path-taking CLI
  arguments in bundled scripts and do not accept custom sanitizer functions as taint
  barriers; scripts must be stdin/stdout only (Step 1 guard). Separately, org scanners
  can attach to a new repository after its first PR merges, so the second PR may fail
  on first-PR code. -> the stdin/stdout rule, and Step 7's JSON-rollup check reading.

## How to use this file

After each packaging run, compare your Run report against your baseline and the most
recent entries. If "human-caught misses" is ever nonzero, the miss belongs in the
ship-plugin skill: propose the edit in the same conversation, and append the incident
here so the next operator inherits the lesson.
