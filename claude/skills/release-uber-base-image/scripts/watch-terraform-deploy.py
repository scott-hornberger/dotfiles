#!/usr/bin/env python3
"""Monitor the terraform deploy build on Buildkite for a given commit.

Runs as a *file* under the Monitor tool (never inline — see
watch-reviews.py for why). Polls the Buildkite REST API for the
`uber/terraform` pipeline build matching a commit SHA and emits one
event line per state change, plus a terminal line when the build
finishes.

Usage:
    BUILDKITE_API_TOKEN=... python3 watch-terraform-deploy.py <commit-sha>

Env:
    BUILDKITE_API_TOKEN   required — Buildkite API access token (read scope)
    BK_ORG                default "uber"
    BK_PIPELINE           default "terraform"
    BK_POLL_SEC           default 30

Events (stdout, one per line):
    BUILD|<state>|<number>|<url>     on first sighting and on each state change
    DONE|passed|<number>|<url>       build finished green
    DONE|<state>|<number>|<url>      build finished non-green (failed/canceled/...)
    WAIT|no build yet for <sha>      emitted once if the build hasn't appeared

Failed polls go to stderr as WATCH-ERR and the loop continues — one API
blip never silences the monitor. Coverage is deliberate: it emits on
EVERY terminal state, not just `passed`, so a failed deploy is never
silent.
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

ORG = os.environ.get("BK_ORG", "uber")
PIPELINE = os.environ.get("BK_PIPELINE", "terraform")
POLL_SEC = int(os.environ.get("BK_POLL_SEC", "30"))


def _load_token():
    """Token from env, else from a token file (set once, reused forever).

    File lookup order:
      $BUILDKITE_TOKEN_FILE, then ~/.config/buildkite/api-token.
    The file may be a bare token or `BUILDKITE_API_TOKEN=...`.
    """
    tok = os.environ.get("BUILDKITE_API_TOKEN", "").strip()
    if tok:
        return tok
    paths = [
        os.environ.get("BUILDKITE_TOKEN_FILE", ""),
        os.path.expanduser("~/.config/buildkite/api-token"),
    ]
    for p in paths:
        if p and os.path.isfile(p):
            raw = open(p).read().strip()
            if raw.startswith("BUILDKITE_API_TOKEN="):
                raw = raw.split("=", 1)[1].strip().strip("\"'")
            if raw:
                return raw
    return ""


TOKEN = _load_token()

# Buildkite terminal build states.
TERMINAL = {"passed", "failed", "canceled", "blocked", "skipped", "not_run"}


def emit(line):
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def warn(msg):
    sys.stderr.write(f"WATCH-ERR|{int(time.time())}|{msg}\n")
    sys.stderr.flush()


def fetch_build(sha):
    url = (
        f"https://api.buildkite.com/v2/organizations/{ORG}"
        f"/pipelines/{PIPELINE}/builds?commit={sha}&per_page=1"
    )
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {TOKEN}"})
    with urllib.request.urlopen(req, timeout=45) as r:
        builds = json.load(r)
    return builds[0] if builds else None


def main():
    if len(sys.argv) < 2:
        warn("usage: watch-terraform-deploy.py <commit-sha>")
        sys.exit(2)
    if not TOKEN:
        warn("BUILDKITE_API_TOKEN not set — cannot reach Buildkite API")
        sys.exit(3)

    sha = sys.argv[1]
    last_state = None
    announced_wait = False

    while True:
        try:
            b = fetch_build(sha)
            if b is None:
                if not announced_wait:
                    emit(f"WAIT|no build yet for {sha[:12]}")
                    announced_wait = True
            else:
                state = b.get("state", "unknown")
                num = b.get("number", "?")
                burl = b.get("web_url", "")
                if state != last_state:
                    emit(f"BUILD|{state}|{num}|{burl}")
                    last_state = state
                if state in TERMINAL:
                    emit(f"DONE|{state}|{num}|{burl}")
                    return
        except urllib.error.HTTPError as e:
            warn(f"HTTP {e.code} {e.reason}")
        except Exception as e:  # noqa: BLE001
            warn(str(e))
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    main()
