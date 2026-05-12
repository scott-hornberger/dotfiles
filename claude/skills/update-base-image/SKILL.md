# Skill: Release uBuild Base Images

## Purpose
Walk an agent through the full process of rebuilding and releasing uBuild Debian base images into the Buildkite CI pipeline configuration. This is a graduated rollout across preprod → high-tier → low-tier (tier 0–2).

## Trigger
Use this skill when asked to:
- "Release the ubuild base image"
- "Rebuild and release base images"
- "Update Debian base images in ubuild"
- "Promote base images to prod"

## References
- [Runbook] Rebuild and release base images: https://docs.google.com/document/d/1sFbMdVtsbYgXH8JdzeK11ZWdppcNwGR_-K0jhTF6OF4
- [Runbook] Release ubuild-build-logic/Pinocchio or pipeline config: https://docs.google.com/document/d/1JaJZvPxnid6r_1GcAwzz1tYAfyo70oDSo2MuHm7L-sY

---

## Phase 1: Check and Build Base Images

### Step 1 — Check freshness of existing builds

Run the following to check the latest successful build for each Debian base image:

```bash
function last_build() { echo $1; ubuild build list $1 2>/dev/null | grep succeeded | tail -1 }

last_build ubi-debian-8
last_build ubi-debian-9
last_build debian-10
last_build debian-11
last_build debian-12
last_build debian-13
```

**Agent action:**
- Parse each output line and note the timestamp of the last successful build.
- Flag any image whose most recent successful build is older than expected (typically > 24 hours if triggered by a dependency update, or > 1 week for routine refreshes).

### Step 2 — Trigger new builds if needed

For any image that is stale or missing a recent build:

```bash
ubuild build create <artifact-name>
# e.g.:
ubuild build create debian-12
ubuild build create debian-13
```

Wait for the builds to complete and confirm all show `succeeded` before proceeding.

---

## Phase 2: Update Pipeline Config (Graduated Rollout)

This is a 4-step graduated rollout: preprod → tier 3–5 → (wait 24h) → tier 0–2.

### Step 3 — Clone the CI repo (if not already present)

```bash
git clone gitolite@code.uber.internal:infra/ci
cd ci
```

### Step 4 — Update base image versions in pipeline config

From `src/terraform/buildkite/pipelines/up-cd/`:

```bash
make update-base-images all
```

- This automatically picks up the latest base image builds from the last 24 hours.
- If no recent builds are found, it will prompt you to create them (go back to Step 2).
- `make all` regenerates the pipeline definitions from the templated `values-*.env` files.

**Agent action:** Confirm the generated diff looks correct — it should bump base image version references in the pipeline configs.

### Step 5 — Land the diff (preprod + tier 3–5)

```bash
# Create and submit the diff for review
arc diff  # or use your standard diff submission workflow
```

- Get the diff approved by a team member.
- Land it and wait for the **Terraform job in Buildkite** to apply the change.

**Agent action:** Monitor the Buildkite pipeline to confirm the Terraform apply completes successfully.

### Step 6 — Run the uBuild smoke test

```bash
# From the root of the go monorepo:
go-code/src/code.uber.internal/infra/ubuild/scripts/smoke-test.sh
```

**Agent action:** All smoke tests must pass before proceeding. If any test fails, do NOT continue the rollout — investigate and fix the issue first.

### Step 7 — Verify health

- Check **Healthline** for any anomalies introduced by the new base images.
- Review **logs** for errors in affected services.
- Confirm the change looks good before promoting further.

### Step 8 — Promote to high-tier + staging pipelines

From `ci/src/terraform/buildkite/pipelines/up-cd/`:

```bash
make promote-preprod
```

- This bumps the version for **high-tier pipelines** and **staging pipelines**.
- Get the resulting diff approved and land it.

### Step 9 — Wait 24 hours

Monitor production traffic and signals for 24 hours after the high-tier promotion.

- This window can be **shortened** for low-risk changes (e.g. routine package bumps with no known CVEs).
- This window should be **extended** for high-risk changes (e.g. new Debian major version, large dependency changes).

### Step 10 — Promote to low-tier (tier 0–2) pipelines

From `src/terraform/buildkite/pipelines/up-cd/`:

```bash
make promote-hightier
```

- Get the diff approved and land it.

### Step 11 — Done ✅

The base image release is fully rolled out across all pipeline tiers.

---

## Rollout Summary

| Step | Action | Command | Gate |
|------|--------|---------|------|
| 1 | Check build freshness | `last_build <image>` | All images fresh? |
| 2 | Rebuild stale images | `ubuild build create <image>` | All succeed? |
| 3 | Clone CI repo | `git clone ...` | — |
| 4 | Update pipeline config | `make update-base-images all` | Diff looks correct? |
| 5 | Land diff → preprod + tier 3–5 | `arc diff` + land | Terraform apply OK? |
| 6 | Run smoke tests | `smoke-test.sh` | All pass? |
| 7 | Verify health | Healthline + logs | No anomalies? |
| 8 | Promote to high-tier + staging | `make promote-preprod` | Diff landed? |
| 9 | Wait 24h | — | Signals healthy? |
| 10 | Promote to tier 0–2 | `make promote-hightier` | Diff landed? |
| 11 | Done | — | — |

---

## Failure Modes & Escalation

| Symptom | Action |
|---------|--------|
| `ubuild build list` shows no recent succeeded builds | Run `ubuild build create <image>` and wait |
| `make update-base-images` prompts for builds | Builds from last 24h are missing — go to Step 2 |
| Terraform apply fails | Check Buildkite logs; may need to re-run or fix config |
| Smoke test failures | Do NOT promote further; investigate failing test |
| Healthline anomaly after high-tier promotion | Consider reverting with `make promote-preprod` using previous versions |
| Unclear owner | Reach out to the uBuild oncall or `#ubuild` Slack channel |
