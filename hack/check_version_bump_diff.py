#!/usr/bin/env python3
"""Fail a pull request that only Open SWE has approved if its diff is not a
plain chart version bump.

A human reviewer is the real gate for every other pull request, so this check
does not apply once one has approved: it exists only to backstop Open SWE's
own approval of PRs it judged to be version-bump-only.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

import yaml

OPEN_SWE_LOGINS = {"open-swe[bot]", "open-swe-preview[bot]", "openswe-dev[bot]"}
STANCE_CHANGING_STATES = {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}
# The chart-name segment is restricted to real directory-name characters
# (no '.', so no '.' or '..') since it flows into `git show <ref>:<path>`.
CHART_FILE_RE = re.compile(r"^charts/([a-zA-Z0-9_-]+)/(Chart\.yaml|values\.yaml|README\.md)$")
ALLOWED_CHART_YAML_KEYS = {"version", "appVersion"}
ALLOWED_VALUES_LEAF_KEY = "tag"


def run(*args: str, timeout: int = 60) -> str:
    return subprocess.run(
        args, check=True, capture_output=True, text=True, timeout=timeout
    ).stdout


def open_swe_only_approval(reviews: list[dict]) -> bool:
    """True only when an Open SWE login's latest review approves and no one else's does.

    GitHub lists reviews oldest-first, and a reviewer's most recent review is
    their current stance for required-review purposes (a later request-changes
    supersedes an earlier approval; a dismissal already shows as DISMISSED).
    COMMENTED and PENDING don't change a reviewer's stance, so they're
    ignored here too: otherwise a comment-only re-review after an approval
    would erase that approval from this check's view, while GitHub itself
    still counts it toward the merge requirement.
    """
    latest_state: dict[str, str] = {}
    for review in reviews:
        login = (review.get("user") or {}).get("login", "")
        state = review.get("state", "")
        if login and state in STANCE_CHANGING_STATES:
            latest_state[login.lower()] = state
    approvers = {login for login, state in latest_state.items() if state == "APPROVED"}
    return bool(approvers) and approvers <= OPEN_SWE_LOGINS


def changed_files(base: str, head: str) -> list[str]:
    diff = run("git", "diff", "--name-only", f"{base}...{head}")
    return [line for line in diff.splitlines() if line]


def load_yaml_at(ref: str, path: str) -> dict:
    return yaml.safe_load(run("git", "show", f"{ref}:{path}")) or {}


def flatten(value: object, prefix: str = "") -> dict[str, object]:
    if isinstance(value, dict):
        out: dict[str, object] = {}
        for key, sub in value.items():
            out.update(flatten(sub, f"{prefix}.{key}" if prefix else str(key)))
        return out
    return {prefix: value}


def check_chart_yaml(base: str, head: str, path: str) -> list[str]:
    old, new = load_yaml_at(base, path), load_yaml_at(head, path)
    if old.keys() != new.keys():
        return [f"{path}: fields were added or removed"]
    return [
        f"{path}: '{key}' changed"
        for key in old
        if old[key] != new[key] and key not in ALLOWED_CHART_YAML_KEYS
    ]


def check_values_yaml(base: str, head: str, path: str) -> list[str]:
    old, new = flatten(load_yaml_at(base, path)), flatten(load_yaml_at(head, path))
    if old.keys() != new.keys():
        return [f"{path}: fields were added or removed"]
    return [
        f"{path}: '{key}' changed"
        for key in old
        if old[key] != new[key] and key.rsplit(".", 1)[-1] != ALLOWED_VALUES_LEAF_KEY
    ]


def charts_readmes_match_helm_docs(chart_names: set[str]) -> list[str]:
    """Regenerate every chart's README and compare, but only look at the
    touched charts' READMEs: they're generated, never hand-edited. Checking
    just the touched ones means an unrelated chart's pre-existing README
    drift can't fail a PR that never touched it. (helm-docs' own
    --chart-to-generate filter is unreliable for some chart names, so this
    regenerates everything and narrows the comparison itself instead.)
    """
    if not chart_names:
        return []
    run("helm-docs", "--chart-search-root=charts", "--template-files=README.md.gotmpl")
    readmes = [f"charts/{name}/README.md" for name in chart_names]
    if run("git", "status", "--porcelain", "--", *readmes).strip():
        return ["a touched chart's README.md is not what helm-docs regenerates from it"]
    return []


def main() -> int:
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    pull_request = event["pull_request"]
    base_sha, head_sha = pull_request["base"]["sha"], pull_request["head"]["sha"]
    repo, number = os.environ["GITHUB_REPOSITORY"], pull_request["number"]

    # --paginate alone prints each page's JSON array back-to-back, which
    # json.loads can't parse past 30 reviews. --slurp wraps the pages into
    # one outer array instead, so flatten that one level to get the reviews.
    pages = json.loads(
        run("gh", "api", f"repos/{repo}/pulls/{number}/reviews", "--paginate", "--slurp")
    )
    reviews = [review for page in pages for review in page]
    if not open_swe_only_approval(reviews):
        print("No approval here relies solely on Open SWE; this check does not apply.")
        return 0

    files = changed_files(base_sha, head_sha)
    problems = [
        f"{path}: not a chart's Chart.yaml, values.yaml, or README.md"
        for path in files
        if not CHART_FILE_RE.match(path)
    ]

    touched_charts = {
        match.group(1) for path in files if (match := CHART_FILE_RE.match(path))
    }
    for path in files:
        if path.endswith("Chart.yaml"):
            problems += check_chart_yaml(base_sha, head_sha, path)
        elif path.endswith("values.yaml"):
            problems += check_values_yaml(base_sha, head_sha, path)
    problems += charts_readmes_match_helm_docs(touched_charts)

    if problems:
        print(
            "Open SWE is the only approval on this pull request, but its diff is not "
            "a plain version bump (chart version/appVersion, image tags, and the "
            "generated README):"
        )
        for problem in problems:
            print(f"  - {problem}")
        print("\nGet a human review, or narrow the diff to just those fields.")
        return 1

    print("Open SWE is the only approval, and the diff is exactly a version bump. OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
