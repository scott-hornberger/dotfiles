#!/usr/bin/env python3
"""Robust Phabricator review-activity watcher for the base-image release flow.

Run under the Monitor tool as a *file* (never inline) so the multi-line
body is not mangled by the harness's eval/shell-snapshot wrapping — that
mangling was the original "always misses" bug.

Usage:
    python3 watch-reviews.py D25310713
    python3 watch-reviews.py PHID-DREV-xxxx
    python3 watch-reviews.py 25310713

Each stdout line is one Monitor event. Emits:
    STATUS|<ts>|<status-name>     when the revision status changes
                                  (e.g. -> Accepted, Needs Revision,
                                  Changes Planned, Closed, Abandoned)
    COMMENT|<ts>|<author>|<body>  for each new human comment

Design choices that make it reliable:
  * Status detection is by differential.revision.search status NAME, not
    by matching transaction `type` strings (those vary across Phab
    versions: accept/reject/request-changes/plan-changes/...). A status
    change is what actually gates landing, so we watch that directly.
  * A failed poll prints WATCH-ERR to STDERR (which Monitor does NOT turn
    into an event) and the loop continues — one transient conduit/auth
    blip never silences the watcher.
  * stdout is line-buffered and every emit flushes.
  * Baseline = state at startup, so only NEW activity is reported. The
    current status is printed once at startup as STATUS|...|<name> so the
    caller always sees a heartbeat confirming the watcher is live and what
    the status already is (catches an accept that landed before startup).
"""
import json
import os
import subprocess
import sys
import time

POLL_SEC = int(os.environ.get("WATCH_POLL_SEC", "60"))


def conduit(method, payload):
    """Call `arc call-conduit <method>`; return parsed response dict or None."""
    p = subprocess.run(
        ["arc", "call-conduit", method],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        timeout=60,
    )
    data = json.loads(p.stdout)
    if data.get("error"):
        raise RuntimeError(f"{method}: {data.get('error_info') or data['error']}")
    return data["response"]


def resolve_phid(ref):
    """Accept D<n>, <n>, or a PHID; return the revision PHID."""
    if ref.startswith("PHID-"):
        return ref
    num = int(ref[1:] if ref[0] in "Dd" else ref)
    resp = conduit("differential.revision.search", {"constraints": {"ids": [num]}})
    return resp["data"][0]["phid"]


def status_name(phid):
    resp = conduit("differential.revision.search", {"constraints": {"phids": [phid]}})
    return resp["data"][0]["fields"]["status"]["name"]


def max_comment_ts(phid):
    resp = conduit("transaction.search", {"objectIdentifier": phid})
    ts = 0
    for t in resp["data"]:
        if t.get("type") == "comment":
            ts = max(ts, int(t["dateCreated"]))
    return ts


def new_comments(phid, since):
    resp = conduit("transaction.search", {"objectIdentifier": phid})
    out = []
    for t in resp["data"]:
        if t.get("type") != "comment":
            continue
        ts = int(t["dateCreated"])
        if ts <= since:
            continue
        au = (t.get("authorPHID") or "")[:20]
        body = " ".join(
            (c.get("content", {}).get("raw", "") or "").replace("\n", " ")
            for c in t.get("comments", [])
        )
        out.append((ts, au, body[:400]))
    return sorted(out)


def emit(line):
    sys.stdout.write(line + "\n")
    sys.stdout.flush()


def warn(msg):
    sys.stderr.write(f"WATCH-ERR|{int(time.time())}|{msg}\n")
    sys.stderr.flush()


def main():
    if len(sys.argv) < 2:
        warn("usage: watch-reviews.py <D-id | revision-id | PHID>")
        sys.exit(2)

    # Resolve PHID with retries — do not give up if the first call blips.
    phid = None
    for _ in range(5):
        try:
            phid = resolve_phid(sys.argv[1])
            break
        except Exception as e:  # noqa: BLE001
            warn(f"resolve_phid: {e}")
            time.sleep(5)
    if not phid:
        warn("could not resolve PHID after retries")
        sys.exit(1)

    last_status = None
    last_comment_ts = 0
    try:
        last_status = status_name(phid)
        last_comment_ts = max_comment_ts(phid)
    except Exception as e:  # noqa: BLE001
        warn(f"startup baseline: {e}")

    # Startup heartbeat so the caller knows the watcher is live + current state.
    emit(f"STATUS|{int(time.time())}|{last_status or 'unknown'} (watcher live)")

    while True:
        time.sleep(POLL_SEC)
        try:
            st = status_name(phid)
            if st != last_status:
                emit(f"STATUS|{int(time.time())}|{st}")
                last_status = st
        except Exception as e:  # noqa: BLE001
            warn(f"status poll: {e}")
        try:
            for ts, au, body in new_comments(phid, last_comment_ts):
                emit(f"COMMENT|{ts}|{au}|{body}")
                last_comment_ts = max(last_comment_ts, ts)
        except Exception as e:  # noqa: BLE001
            warn(f"comment poll: {e}")


if __name__ == "__main__":
    main()
