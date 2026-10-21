#!/usr/bin/env python3
"""Fail a pull request that no human has approved unless its diff is a plain
chart version bump.

The required-workflow ruleset runs this on push, before anyone has reviewed.
A version bump is already green then, so Open SWE can approve it later and
it can merge. Anything else stays red until a human has approved and this
runs again.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

OPEN_SWE_LOGINS = {"open-swe[bot]", "open-swe-preview[bot]", "openswe-dev[bot]"}
STANCE_CHANGING_STATES = {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}
# The chart-name segment is restricted to real directory-name characters
# (no '.', so no '.' or '..') since it flows into `git show <ref>:<path>`.
CHART_FILE_RE = re.compile(r"^charts/([a-zA-Z0-9_-]+)/(Chart\.yaml|values\.yaml|README\.md)$")
ALLOWED_CHART_YAML_KEYS = {"version", "appVersion"}
ALLOWED_VALUES_LEAF_KEY = "tag"


def run(*args: str, timeout: int = 60, cwd: str | None = None) -> str:
    return subprocess.run(
        args, check=True, capture_output=True, text=True, timeout=timeout, cwd=cwd
    ).stdout


def human_has_approved(reviews: list[dict]) -> bool:
    """True when a non-Open-SWE login's latest stance-changing review approves.

    GitHub lists reviews oldest-first. Only APPROVED, CHANGES_REQUESTED, and
    DISMISSED change a stance; a later COMMENTED review does not erase an
    earlier approval.
    """
    latest_state: dict[str, str] = {}
    for review in reviews:
        login = (review.get("user") or {}).get("login", "")
        state = review.get("state", "")
        if login and state in STANCE_CHANGING_STATES:
            latest_state[login.lower()] = state
    return any(
        state == "APPROVED" and login not in OPEN_SWE_LOGINS
        for login, state in latest_state.items()
    )


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


def charts_readmes_match_helm_docs(head: str, chart_names: set[str]) -> list[str]:
    """Regenerate the touched charts' READMEs from the PR head and compare
    against what's committed there: they're generated, never hand-edited.
    Runs helm-docs in a throwaway worktree of the head ref so this check
    never needs the PR's content to be the checked-out working tree.
    """
    if not chart_names:
        return []

    with tempfile.TemporaryDirectory() as tmp:
        run("git", "worktree", "add", "--detach", tmp, head)
        try:
            run(
                "helm-docs",
                "--chart-search-root=charts",
                "--template-files=README.md.gotmpl",
                cwd=tmp,
            )
            readmes = [f"charts/{name}/README.md" for name in chart_names]
            dirty = run("git", "status", "--porcelain", "--", *readmes, cwd=tmp).strip()
        finally:
            run("git", "worktree", "remove", "--force", tmp)
    if dirty:
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
    if human_has_approved(reviews):
        print("A human has approved; this check does not apply.")
        return 0

    files = changed_files(base_sha, head_sha)
    problems = [
        f"{path}: not a chart's Chart.yaml, values.yaml, or README.md"
        for path in files
        if not CHART_FILE_RE.match(path)
    ]
    # The guard's own workflow and checker must never be changeable by a PR
    # that only Open SWE approved: otherwise that PR could edit the workflow
    # that runs on pull_request_review (which uses the PR's own copy of the
    # file) to report this check as passing for real.
    problems += [
        f"{path}: changes the version-bump guard's own workflow or checker"
        for path in files
        if path.startswith(".github/") or path.startswith("hack/")
    ]

    touched_charts = {
        match.group(1) for path in files if (match := CHART_FILE_RE.match(path))
    }
    for path in files:
        if path.endswith("Chart.yaml"):
            problems += check_chart_yaml(base_sha, head_sha, path)
        elif path.endswith("values.yaml"):
            problems += check_values_yaml(base_sha, head_sha, path)
    problems += charts_readmes_match_helm_docs(head_sha, touched_charts)

    if problems:
        print(
            "No human has approved this pull request, and its diff is not a plain "
            "version bump (chart version/appVersion, image tags, and the generated "
            "README):"
        )
        for problem in problems:
            print(f"  - {problem}")
        print("\nGet a human review, or narrow the diff to just those fields.")
        return 1

    print("No human has approved, and the diff is exactly a version bump. OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
