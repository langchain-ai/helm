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
from collections.abc import Mapping
from pathlib import Path

import yaml

OPEN_SWE_LOGINS = {"open-swe[bot]", "open-swe-preview[bot]", "openswe-dev[bot]"}
STANCE_CHANGING_STATES = {"APPROVED", "CHANGES_REQUESTED", "DISMISSED"}
# The chart-name segment is restricted to real directory-name characters
# (no '.', so no '.' or '..') since it flows into `git show <ref>:<path>`.
CHART_FILE_RE = re.compile(r"^charts/([a-zA-Z0-9_-]+)/(Chart\.yaml|values\.yaml|README\.md)$")
PR_IN_REF_RE = re.compile(r"(?:^|/)pr-(\d+)(?=-|$)")
ALLOWED_CHART_YAML_KEYS = {"version", "appVersion"}
ALLOWED_VALUES_LEAF_KEY = "tag"
REGULAR_FILE_MODE = "100644"


def run(
    *args: str,
    timeout: int = 60,
    cwd: str | None = None,
    env: dict[str, str] | None = None,
) -> str:
    return subprocess.run(
        args,
        check=True,
        capture_output=True,
        text=True,
        timeout=timeout,
        cwd=cwd,
        env=env,
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


def regular_file_problems(path: str, base_mode: str | None, head_mode: str | None) -> list[str]:
    problems = []
    for label, mode in (("base", base_mode), ("head", head_mode)):
        if mode is not None and mode != REGULAR_FILE_MODE:
            problems.append(
                f"{path}: {label} is mode {mode}, not a regular {REGULAR_FILE_MODE} file"
            )
    return problems


def file_mode(ref: str, path: str) -> str | None:
    entry = run("git", "ls-tree", ref, "--", path).strip()
    return entry.split(maxsplit=1)[0] if entry else None


def changed_files(base: str, head: str) -> list[str]:
    diff = run("git", "diff", "--no-renames", "--name-only", f"{base}...{head}")
    return [line for line in diff.splitlines() if line]


def load_yaml_at(ref: str, path: str) -> dict:
    return yaml.safe_load(run("git", "show", f"{ref}:{path}")) or {}


def compare_values(
    old: object, new: object, path: tuple[str, ...] = ()
) -> list[str]:
    if isinstance(old, Mapping) and isinstance(new, Mapping):
        old_keys, new_keys = set(old), set(new)
        problems = []
        if old_keys != new_keys:
            location = ".".join(path) or "<root>"
            problems.append(f"'{location}' fields were added or removed")
        for key in old_keys & new_keys:
            problems += compare_values(old[key], new[key], (*path, str(key)))
        return problems

    if isinstance(old, Mapping) or isinstance(new, Mapping):
        location = ".".join(path) or "<root>"
        return [f"'{location}' changed mapping structure"]

    if path and path[-1] == ALLOWED_VALUES_LEAF_KEY:
        if old == new:
            return []
        old_ok = isinstance(old, str) and "\n" not in old
        new_ok = isinstance(new, str) and "\n" not in new
        if old_ok and new_ok:
            return []
        location = ".".join(path)
        return [f"'{location}' must stay a scalar image tag"]

    if old != new and (not path or path[-1] != ALLOWED_VALUES_LEAF_KEY):
        location = ".".join(path) or "<root>"
        return [f"'{location}' changed"]
    return []


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
    old, new = load_yaml_at(base, path), load_yaml_at(head, path)
    return [f"{path}: {problem}" for problem in compare_values(old, new)]


def charts_readmes_match_helm_docs(head: str, chart_names: set[str]) -> list[str]:
    """Regenerate the touched charts' READMEs from the PR head and compare
    against what's committed there: they're generated, never hand-edited.
    Runs helm-docs in a throwaway worktree of the head ref so this check
    never needs the PR's content to be the checked-out working tree.
    """
    if not chart_names:
        return []

    helm_env = {
        key: os.environ[key]
        for key in ("PATH", "TMPDIR", "LANG", "LC_ALL")
        if key in os.environ
    }
    with tempfile.TemporaryDirectory() as tmp:
        run("git", "worktree", "add", "--detach", tmp, head)
        try:
            run(
                "helm-docs",
                "--chart-search-root=charts",
                "--template-files=README.md.gotmpl",
                cwd=tmp,
                env=helm_env,
            )
            readmes = [f"charts/{name}/README.md" for name in chart_names]
            dirty = run("git", "status", "--porcelain", "--", *readmes, cwd=tmp).strip()
        finally:
            run("git", "worktree", "remove", "--force", tmp)
    if dirty:
        return ["a touched chart's README.md is not what helm-docs regenerates from it"]
    return []


def pull_numbers_from_ref(ref: str) -> list[int]:
    return [int(number) for number in PR_IN_REF_RE.findall(ref)]


def event_targets(event: Mapping) -> tuple[str, str, list[int]]:
    """Return the diff endpoints and every pull request the event represents."""
    pull_request = event.get("pull_request")
    if isinstance(pull_request, Mapping):
        base = pull_request.get("base")
        head = pull_request.get("head")
        number = pull_request.get("number")
        base_sha = base.get("sha") if isinstance(base, Mapping) else None
        head_sha = head.get("sha") if isinstance(head, Mapping) else None
        if isinstance(number, int) and isinstance(base_sha, str) and isinstance(head_sha, str):
            return base_sha, head_sha, [number]
        raise ValueError("pull_request event is missing its number or shas")

    group = event.get("merge_group")
    if not isinstance(group, Mapping):
        raise ValueError("event has neither pull_request nor merge_group")
    base_sha, head_sha, ref = group.get("base_sha"), group.get("head_sha"), group.get("head_ref")
    if not isinstance(base_sha, str) or not isinstance(head_sha, str):
        raise ValueError("merge_group event is missing its shas")
    return base_sha, head_sha, pull_numbers_from_ref(ref if isinstance(ref, str) else "")


def pull_numbers_between(repo: str, base: str, head: str) -> list[int]:
    shas = [line for line in run("git", "rev-list", f"{base}..{head}").splitlines() if line]
    numbers: list[int] = []
    for sha in shas:
        payload = json.loads(
            run(
                "gh",
                "api",
                "-H",
                "Accept: application/vnd.github+json",
                f"repos/{repo}/commits/{sha}/pulls",
            )
        )
        if not isinstance(payload, list):
            raise ValueError(f"pull list for commit {sha} was not a list")
        for pull in payload:
            number = pull.get("number") if isinstance(pull, Mapping) else None
            if isinstance(number, int) and number not in numbers:
                numbers.append(number)
    return numbers


def reviews_for(repo: str, number: int) -> list[dict]:
    # --paginate alone prints each page's JSON array back-to-back, which
    # json.loads can't parse past 30 reviews. --slurp wraps the pages into
    # one outer array instead, so flatten that one level to get the reviews.
    pages = json.loads(
        run("gh", "api", f"repos/{repo}/pulls/{number}/reviews", "--paginate", "--slurp")
    )
    if not isinstance(pages, list):
        raise ValueError(f"reviews for pull request {number} were not paginated")
    return [review for page in pages for review in page]


def main() -> int:
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    try:
        base_sha, head_sha, numbers = event_targets(event)
    except ValueError as error:
        print(f"Cannot identify the changes to check: {error}")
        return 1
    repo = os.environ["GITHUB_REPOSITORY"]
    if "merge_group" in event:
        for number in pull_numbers_between(repo, base_sha, head_sha):
            if number not in numbers:
                numbers.append(number)

    if numbers and all(human_has_approved(reviews_for(repo, number)) for number in numbers):
        print("A human has approved; this check does not apply.")
        return 0

    files = changed_files(base_sha, head_sha)
    problems = [
        f"{path}: not a chart's Chart.yaml, values.yaml, or README.md"
        for path in files
        if not CHART_FILE_RE.match(path)
    ]
    for path in files:
        if CHART_FILE_RE.match(path):
            problems += regular_file_problems(
                path, file_mode(base_sha, path), file_mode(head_sha, path)
            )
    if problems:
        print("No human has approved, and disallowed paths changed:")
        for problem in problems:
            print(f"  - {problem}")
        return 1

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
