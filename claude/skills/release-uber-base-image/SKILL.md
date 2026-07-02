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
- **Autoland tag**: NO — `infra/ci` has no SubmitQueue, so the
  `autoland` Phab project tag does nothing. Don't bother adding it
  (confirmed by `arc call-conduit /api/v2/queues` — no `infra-ci`
  queue exists). Landing happens via `arc land` from this checkout.
- **Branch name**: descriptive slug per phase, not the JIRA key:
  - Phase 1: `bump-preprod-debian-base-images`
  - Phase 2: `promote-hightier-debian-base-images`
  - Phase 4: `promote-lowtier-debian-base-images`
- **Auto-land behavior**: YES — once the diff is Accepted AND CI is
  green, land it yourself with `command arc land`. Do not pause for
  user confirmation. The user explicitly delegated landing
  (2026-06-17: "Always land it yourself when it is ready to land").

Only re-ask if the user overrides one in the current session.

## Monitor → Address → Land (post-diff-create workflow)

After `arc diff --create` succeeds, kick off the autonomous landing
flow. Two pollers run in parallel under the Monitor tool — both are
zero-LLM-token until something changes.

**FIRST — remind the user to request review from a teammate**, even
though METADATA auto-assigns reviewers (e.g. `up-cd`, `sjuul` for
this path). The auto-assigned reviewers may not be available; an
explicit ping in #ubuild Slack or a direct message to a teammate
unblocks landing faster. Use `PushNotification`:

```
PushNotification("D<N> is up — please ping a teammate for review (auto-assigned: up-cd / sjuul)")
```

Include the diff URL in the user-facing message too.

```
diff created ─┬─ babysit-diff (CI status)     ─┐
              └─ comment watcher (reviews)    ─┴─> when BOTH ready ─> arc land
```

### Pollers to launch

1. **CI**: `Skill("uber-dev:babysit-diff")` with the diff ID. Wakes
   on `fix_needed`, `green`, or `stuck`.
2. **Reviewer activity**: run the committed watcher SCRIPT under
   `Monitor(persistent=true)`. Pass the diff id directly — it resolves
   the PHID itself:
   ```
   Monitor(
     command="python3 <skill_base_dir>/scripts/watch-reviews.py D<N>",
     description="reviewer activity on D<N>",
     persistent=true,
   )
   ```
   `<skill_base_dir>` is the "Base directory for this skill:" path in the
   skill header (the `~/.claude/...` symlink resolves into `~/.dotfiles`).
   The script emits one event per line:
   - `STATUS|<ts>|<name>` on every revision status CHANGE — the one you
     care about is `... |Accepted`. It also prints a startup heartbeat
     `STATUS|<ts>|<name> (watcher live)` so you can confirm it's running
     and see the current status (catches an accept that landed before
     the watcher started).
   - `COMMENT|<ts>|<author>|<body>` for each new human comment.

   **Do NOT re-inline this as a bash+python blob under Monitor.** That
   was the original "always misses" bug: the Monitor harness wraps the
   command in an `eval`/shell-snapshot that mangles multi-line inline
   python, the parse step hits its `except` and silently `exit(0)`s, and
   the watcher goes dark forever while looking alive in `ps`. The filter
   logic was provably correct in isolation — the *delivery* was broken.
   A standalone script file sidesteps eval entirely. The script also (a)
   detects readiness by status NAME via `differential.revision.search`
   rather than by guessing transaction `type` strings, and (b) treats a
   failed poll as a stderr `WATCH-ERR` and keeps going, so one conduit
   blip can't silence it.

   **Requires `php` on PATH** (`arc call-conduit` is a PHP CLI;
   `brew autoremove` after `brew install uber/alt/ubuild-cli` will
   silently nuke `php@8.x`. Fix: `brew link --overwrite php@8.4`).

### Reacting to events

| Event | Action |
|-------|--------|
| `babysit-diff: green` | If status is already Accepted → run land step. Otherwise stop the CI poller and keep waiting for review. |
| `babysit-diff: fix_needed` | Read pre-extracted errors, fix, commit, `command arc diff` to update D<N>. |
| `STATUS \| ... \| Accepted` | If CI is green → run land step. Otherwise wait for green. |
| `STATUS \| ... \| Needs Revision` / `Changes Planned` | Read the comment(s), address them per "Addressing comments" below. |
| `COMMENT \| ...` | Read body. If it's a question → reply via `command arc call-conduit differential.revision.edit` with a `comment` transaction. If it's a change request → treat like Needs Revision. If purely informational → no action. |
| `STATUS \| ... \| Closed` / `Abandoned` | Diff landed or abandoned — stop all pollers and report to user. |
| `STATUS \| ... \| (watcher live)` | Startup heartbeat — confirms the watcher is up; note the current status, take no other action. |

> The watcher reports the revision **status name** (from
> `differential.revision.search`), not a transaction `type`. "Accepted"
> is the land gate; "Needs Revision"/"Changes Planned" mean address
> comments; "Closed"/"Abandoned" are terminal. `WATCH-ERR` lines go to
> stderr and are NOT events — if you suspect the watcher is unhealthy,
> `Read` its Monitor output file to see them.

### Addressing comments

For each reviewer comment that asks for a change:
1. Make the code change in the working tree.
2. Re-run the appropriate Phase Step 1 procedure if the change
   affects values/YAMLs (so the filter re-runs).
3. `command arc diff` (with the `arc` shell-function wrapper bypass)
   to update D<N>. Wrapper amends the commit automatically via
   `--amend-all --use-commit-message HEAD`.
4. Post a reply on the diff acknowledging the fix:
   ```bash
   echo '{"objectIdentifier":"<PHID>","transactions":[
     {"type":"comment","value":"Addressed in latest revision: <one-line summary>"}
   ]}' | command arc call-conduit differential.revision.edit
   ```

If a comment is ambiguous or asks something only the user can
decide, post a reply asking, and ping the user with `PushNotification`.

### Landing

When CI is green AND status is Accepted, land:

```bash
# Refresh master first (someone else may have landed something)
git fetch origin master
# Confirm only DEBIAN/BAZEL lines moved on master in our files (cheap sanity)
git log --name-only --pretty=format: HEAD..origin/master \
  | grep -E 'values-preprod\.env|ubuild-(multi-arch-)?preprod\.yml' | sort -u
# Land
command arc land
```

Notes:
- Use `command arc land` (not `arc land`) — the user's `arc` shell
  wrapper only special-cases `arc diff`, but explicit `command`
  is consistent and harmless.
- `arc land` auto-rebases onto the latest master and pushes
  directly to `origin master`. It runs the IMP vref check via
  gitolite hooks; expect output like
  `😈: Controlling D<N> (N file(s) changed, reviewed by: ..., committed by: ...)`.
- **Do NOT use `arc land --hold && git push <sha>:master`** — the
  Claude auto-mode classifier blocks raw pushes to `master` as
  bypassing the review flow, even when `arc land --hold` produced
  the merge commit. Just run `arc land` directly; it pushes itself.
- After landing, ALWAYS auto-launch the terraform-deploy monitor (see
  "Monitoring the terraform deploy" below) before smoke-testing
  (Phase 1 Step 3). Never ask whether to monitor — always monitor.

### Monitoring the terraform deploy (ALWAYS, never ask)

After every land, the merge auto-triggers a `uber/terraform` deploy.
ALWAYS monitor it to completion — do NOT ask the user "want me to
monitor or pause?". Launch the committed monitor script under
`Monitor(persistent=true)`, passing the merge commit SHA (from the
`arc land` output, e.g. `07bcd4788..d90b874f1`):

```
Monitor(
  command="python3 <skill_base_dir>/scripts/watch-terraform-deploy.py <merge-sha>",
  description="terraform deploy for <merge-sha>",
  persistent=true,
)
```

Events: `BUILD|<state>|<num>|<url>` on each state change, then a
terminal `DONE|passed|...` (proceed to smoke test) or
`DONE|failed|...` / `DONE|canceled|...` (stop, report, do not promote
the next tier). It emits on EVERY terminal state, so a failed deploy is
never silent.

**One-time token setup (credential, not a "monitor?" question).** The
Buildkite API needs a token. The script reads `BUILDKITE_API_TOKEN`
from env, else from `~/.config/buildkite/api-token` (bare token or
`BUILDKITE_API_TOKEN=...`). If that file is missing, the script exits
with `WATCH-ERR|...|BUILDKITE_API_TOKEN not set`; ask the user ONCE to
create it (`mkdir -p ~/.config/buildkite && printf '%s' '<token>' >
~/.config/buildkite/api-token && chmod 600 ~/.config/buildkite/api-token`),
then relaunch. This is the only thing you may ask about re: deploy
monitoring — never ask whether to monitor.

### Safety stops

- If `babysit-diff` reports `fix_needed` more than 3 times for the
  same root cause, stop and ask the user.
- If a reviewer leaves a comment that the skill cannot address
  with a simple code change (e.g. "are you sure?", "let's discuss"),
  post a reply asking for clarification and ping the user.
- Never land while CI is RUNNING.
- Never land before status is Accepted (arc land will refuse with
  "This revision has not been accepted." — listen to it).

## References

- Project conventions: `CLAUDE.md` (repo root of `infra/ci`)
- Terraform deploy pipeline: https://buildkite.com/uber/terraform/builds/
- Working directory: `src/terraform/buildkite/pipelines/up-cd/` in `infra/ci`

---

## Step 0 — Detect current state (ALWAYS run first)

### Step 0a — Get a clean master FIRST (non-negotiable)

ALWAYS sync to a clean `origin/master` before reading any state. The
rollout state is derived from the values files, and a stale local
checkout will produce a WRONG state diagnosis — every downstream
decision (which builds are "latest", whether tiers are equal, what a
diff would change) is then garbage. A stale local `master` also poisons
`arc`'s diff base, which can balloon a 3-file diff into a 100+-file one.

```bash
cd src/terraform/buildkite/pipelines/up-cd
git fetch origin master
git checkout master
git reset --hard origin/master   # local master MUST equal origin/master
git status --short                # must be empty
```

Do NOT skip this even if the tree "looks clean" — `git status` clean
only means no uncommitted edits; it says nothing about how far behind
`origin/master` your local HEAD is. Confirm `git rev-parse HEAD` ==
`git rev-parse origin/master` before continuing.

If the working tree has local changes you can't discard, stop and ask
the user rather than `reset --hard`.

### Step 0b — Detect current state

The rollout state lives entirely in the working tree + git history. Run
these from `src/terraform/buildkite/pipelines/up-cd/` (after Step 0a):

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

Hand off to the autonomous flow in **"Monitor → Address → Land"
(post-diff-create workflow)** above:

1. `Skill("uber-dev:diff-create")` with the Diff defaults
   (JIRA=`UPCD-3`, autoland skipped, branch=`bump-preprod-debian-base-images`).
   Commit message: `Bump preprod Debian base images` (matches prior
   atanwir commits — short, no "release:" prefix).
2. **Remind the user to request review from a teammate** —
   `PushNotification` with the diff URL and the auto-assigned
   reviewers; let them know which person to ping.
3. Launch CI poller + comment watcher.
4. React to events per the table; address any reviewer comments.
5. When CI green AND Accepted → `command arc land`.

After landing, ALWAYS auto-launch the terraform-deploy monitor (see
"Monitoring the terraform deploy") for the merge SHA and wait for
`DONE|passed` before the smoke test. Never ask whether to monitor.

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

Same autonomous flow as Phase 1 Step 2 — diff-create with Diff
defaults (branch=`promote-hightier-debian-base-images`), remind the
user to ping a teammate for review, launch the two pollers, address
comments, `command arc land` when ready.

Suggested commit message:

```
Promote Debian base images preprod → hightier
```

Auto-launch the terraform-deploy monitor (see "Monitoring the terraform
deploy") for the merge SHA and wait for `DONE|passed`. Never ask whether
to monitor.

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

Same autonomous flow as Phase 1/2 Step 2 — diff-create with Diff
defaults (branch=`promote-lowtier-debian-base-images`), remind the
user to ping a teammate for review, launch the two pollers, address
comments, `command arc land` when ready.

Suggested commit message:

```
Promote Debian base images hightier → lowtier
```

Auto-launch the terraform-deploy monitor (see "Monitoring the terraform
deploy") for the merge SHA and wait for `DONE|passed`. Never ask whether
to monitor.

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
