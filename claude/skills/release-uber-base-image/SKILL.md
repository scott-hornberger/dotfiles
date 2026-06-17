---
name: release-uber-base-image
description: Release Debian base images (debian-8/9/10/11/12/13) through the multi-day 4-stage graduated rollout — preprod → smoke test → tier 3-5 → 24h soak → tier 0-2. Multi-session aware: detects current phase from values-*.env files and git history, picks up where it left off. Use when asked to "release base images", "rebuild and release base images", "promote base images", "update Debian base images", "continue the base image release", or "where am I in the base image rollout". For releasing ubuild-build-logic / Pinocchio / Makisu / non-base-image pipeline config, use the broader release-up-cd flow instead.
---

# Skill: Release uBuild Debian base images (multi-day)

Walk through the safe, multi-day rollout of Debian base image bumps across
all uBuild pipeline tiers. The skill is **resumable** — invoke it at any
point in the rollout and it will figure out where you are and what's next.

## Scope (do NOT violate)

- Touch ONLY `DEBIAN_*_BASE_IMAGE` lines. Do not bump `UBUILD_IMAGE`,
  `MAKISU_IMAGE`, `PINOCCHIO_IMAGE`, `PROXY_IMAGE`, or any `*_VERSION`
  lines — those are separate release tracks.
- Touch ONLY the three production env files: `values-preprod.env`,
  `values-hightier.env`, `values-lowtier.env`. Do not update any
  `values-staging*.env` files. (The staging pipelines pick up changes
  through the `promote-preprod` copy step automatically.)
- Never run `deploy*.sh` locally — those are CI-only.
- Always commit and land between phases. Don't bundle preprod +
  hightier + lowtier into one diff.

## Diff defaults (do NOT re-ask)

When handing off to `uber-dev:diff-create` (or doing the equivalent
inline), apply these without asking the user:

- **JIRA**: `UPCD-3` — long-lived umbrella ticket for routine base
  image rollouts. Prior commit message bodies render it as
  "T3-UPCD-3" (Phabricator display form), but Conduit's
  `uber-jira.issues` field accepts only `UPCD-3` (no `T3-` prefix);
  passing `T3-UPCD-3` returns ERR-CONDUIT-CORE.
- **Autoland**: NO — user lands manually after reviewing diff +
  terraform plan.
- **Branch name**: descriptive slug per phase, not the JIRA key:
  - Phase 1: `bump-preprod-debian-base-images`
  - Phase 2: `promote-hightier-debian-base-images`
  - Phase 4: `promote-lowtier-debian-base-images`

Only re-ask if the user overrides one in the current session.

## References

- Project conventions: `CLAUDE.md` (repo root of `infra/ci`)
- Terraform deploy pipeline: https://buildkite.com/uber/terraform/builds/
- Working directory: `src/terraform/buildkite/pipelines/up-cd/` in `infra/ci`

---

## Step 0 — Detect current state (ALWAYS run first)

The rollout state lives entirely in the working tree + git history. Run
these from `src/terraform/buildkite/pipelines/up-cd/`:

```bash
cd src/terraform/buildkite/pipelines/up-cd

# Current versions in each tier (base images only)
echo "=== preprod ==="; grep '_BASE_IMAGE=' values-preprod.env
echo "=== hightier ==="; grep '_BASE_IMAGE=' values-hightier.env
echo "=== lowtier ==="; grep '_BASE_IMAGE=' values-lowtier.env

# Last commit time on each values file
git log -1 --format='%ci  %h  %s' -- values-preprod.env
git log -1 --format='%ci  %h  %s' -- values-hightier.env
git log -1 --format='%ci  %h  %s' -- values-lowtier.env

# Uncommitted changes?
git status --short values-preprod.env values-hightier.env values-lowtier.env \
  ubuild-*.yml continuous-deployment-reconciler.yml
```

Compare ONLY the `DEBIAN_*_BASE_IMAGE` lines. Then match against:

| `git diff` between files (HEAD)                  | Working tree            | State                | Next step                                       |
|--------------------------------------------------|-------------------------|----------------------|-------------------------------------------------|
| preprod == hightier == lowtier                   | clean                   | **FRESH / DONE**     | If you want a new release: Phase 1 Step 1. If you just finished: nothing to do. |
| preprod == hightier == lowtier                   | preprod modified        | **PREPROD_DIRTY**    | Phase 1 Step 2 (review + land the preprod diff) |
| preprod ≠ hightier, hightier == lowtier          | clean                   | **PREPROD_LANDED**   | Phase 1 Step 3 (smoke + verify); then Phase 2   |
| preprod ≠ hightier, hightier == lowtier          | hightier modified       | **HIGHTIER_DIRTY**   | Phase 2 Step 2 (review + land the hightier diff)|
| preprod == hightier, hightier ≠ lowtier          | clean                   | **HIGHTIER_LANDED**  | Phase 3 (soak check) → Phase 4                  |
| preprod == hightier, hightier ≠ lowtier          | lowtier modified        | **LOWTIER_DIRTY**    | Phase 4 Step 2 (review + land the lowtier diff) |

State the detected state out loud to the user before proceeding, e.g.
"Detected state: HIGHTIER_LANDED — hightier was promoted 18h ago, 6h of
soak remaining before lowtier promotion." This makes resume behavior
explicit and gives the user a chance to redirect.

If the working tree has changes to non-base-image lines (`UBUILD_IMAGE`,
`PINOCCHIO_IMAGE`, etc.) or to staging env files, **stop and ask the
user** — those are out of scope for this skill.

For the soak timer in HIGHTIER_LANDED:

```bash
hightier_landed_at=$(git log -1 --format=%ct -- values-hightier.env)
elapsed_h=$(( ( $(date +%s) - hightier_landed_at ) / 3600 ))
echo "Hightier landed ${elapsed_h}h ago (default soak: 24h)"
```

If `elapsed_h < 24`, do NOT promote to lowtier without the user
explicitly shortening the soak.

---

## Phase 1 — Preprod

### Step 1 — Refresh base image versions

```bash
cd src/terraform/buildkite/pipelines/up-cd
make update-base-images all
```

What this does:
- `update-base-images.sh` reads `ubuild build list` for each
  `debian-{8,9,10,11,12,13}` image, finds the latest build that came
  from `base-image-build-validator` (i.e. from main), confirms it
  succeeded, confirms it's < 24h old, and rewrites the matching
  `DEBIAN_*_BASE_IMAGE` line in `values-preprod.env`.
- `make all` then regenerates the pipeline YAMLs from the values.

If the script exits because a build is missing or stale, run
`ubuild build create <artifact>` for the named image, wait for
`succeeded`, then re-run `make update-base-images all`.

Inspect the diff:

```bash
git diff values-preprod.env ubuild-*.yml continuous-deployment-reconciler.yml
```

It should touch only:
- `DEBIAN_*_BASE_IMAGE` lines in `values-preprod.env`
- Generated `ubuild-*preprod*.yml` files (preprod-tier pipelines)
- `continuous-deployment-reconciler.yml` if applicable
- NOT any hightier/lowtier YAMLs

If other lines moved, investigate before continuing.

### Step 2 — Land the preprod diff

Use the project's standard PR/diff workflow. The
`uber-dev:diff-create` and `uber-dev:babysit-diff` skills handle this
end-to-end. Commit message convention from recent history:

```
release: bump debian base images to <date> builds (preprod)
```

After landing, watch https://buildkite.com/uber/terraform/builds/ until
the terraform apply succeeds.

### Step 3 — Smoke test + health verification

From the go monorepo:

```bash
go-code/src/code.uber.internal/infra/ubuild/scripts/smoke-test.sh
```

All smoke tests must pass. Then check:
- Healthline for any new anomalies on ubuild-* services
- Buildkite job logs for any error patterns

**If anything looks off, stop and roll back preprod before promoting.**

---

## Phase 2 — Tier 3-5 (hightier + staging)

### Step 1 — Promote preprod → hightier

```bash
cd src/terraform/buildkite/pipelines/up-cd
make promote-preprod
```

This is just `cp values-preprod.env values-hightier.env && ./scripts/generate.sh`.
The generated YAMLs for hightier + staging pipelines update accordingly.

Inspect the diff:

```bash
git diff values-hightier.env ubuild-*.yml
```

Verify only base image lines moved in `values-hightier.env` (preprod
should already have been base-image-only from Phase 1).

### Step 2 — Land the hightier diff

Same PR/diff flow as Phase 1 Step 2. Suggested message:

```
release: promote debian base images preprod → hightier
```

Wait for terraform apply.

---

## Phase 3 — 24h Soak

Hightier covers tier 3-5 prod pipelines. Let them run for 24h before
promoting to tier 0-2 (lowtier).

```bash
hightier_landed_at=$(git log -1 --format=%ct -- values-hightier.env)
elapsed_h=$(( ( $(date +%s) - hightier_landed_at ) / 3600 ))
remaining_h=$(( 24 - elapsed_h ))
echo "Soak: ${elapsed_h}h elapsed, ${remaining_h}h remaining"
```

During the soak:
- Monitor Healthline + #ubuild Slack channel
- If issues surface, stop the rollout and roll back hightier — do not
  promote lowtier to "outrun" the problem

The 24h window can be:
- **Shortened** for low-risk changes (routine package bumps, no CVEs) —
  must be explicitly approved by the user
- **Extended** for high-risk changes (new Debian major, large dependency
  shifts) — set a reminder

This phase typically ends a session. Future invocations of this skill
will detect state HIGHTIER_LANDED and resume here.

---

## Phase 4 — Tier 0-2 (lowtier)

### Step 1 — Promote hightier → lowtier

Confirm soak elapsed ≥ 24h (or the user's chosen window) before proceeding.

```bash
cd src/terraform/buildkite/pipelines/up-cd
make promote-hightier
```

This is `cp values-hightier.env values-lowtier.env && ./scripts/generate.sh`.

Inspect the diff:

```bash
git diff values-lowtier.env ubuild-*.yml
```

### Step 2 — Land the lowtier diff

Suggested message:

```
release: promote debian base images hightier → lowtier
```

Wait for terraform apply.

---

## Done

Release is fully rolled out across preprod, tier 3-5, and tier 0-2.
Keep an eye on Healthline / oncall for the next few hours. Brace for
impact.

---

## Failure modes

| Symptom                                           | Action                                                                              |
|---------------------------------------------------|-------------------------------------------------------------------------------------|
| `update-base-images.sh`: "No build validator found" | Trigger `ubuild build create <image>`; wait for `succeeded`; re-run               |
| `update-base-images.sh`: "older than 24 hours"    | Same — kick a fresh build                                                          |
| `update-base-images.sh`: status != `succeeded`    | Investigate the failed build; do not work around by forcing a tag                  |
| `make all` modified non-base-image lines          | Stop; user is releasing something else, switch to release-up-cd                    |
| Generated diff includes staging env files         | Bug — only `make promote-preprod` should update staging YAMLs; investigate before landing |
| Terraform deploy job fails                        | Check Buildkite logs; fix forward or revert; do not skip phases                    |
| Smoke tests fail after preprod                    | Stop; do not promote to hightier; investigate                                      |
| Healthline anomaly after hightier                 | Roll back hightier (`make promote-preprod` with PREVIOUS preprod values); do not promote lowtier |
| Unclear owner / blocked                           | #ubuild Slack channel or uBuild oncall                                             |

## Notes for the agent

- The skill is idempotent — re-running Step 0 always tells you what's next.
- If state detection is ambiguous (e.g. `values-preprod.env` modified in
  ways that don't match the templates), stop and ask the user rather than
  guessing.
- After each `make` invocation, ALWAYS inspect the YAML diff before
  committing. Templates can drift in unexpected ways.
- The 24h soak gate is a safety property — even if a script could
  automate the wait, do not chain phases in one session.
