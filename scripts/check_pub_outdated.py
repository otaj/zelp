#!/usr/bin/env python3
"""Fail when direct/dev pub deps can be upgraded with `pub upgrade`, or are unsafe.

Policy (practical, non-flaky):
  For each package with kind "direct" or "dev":
    - Fail if discontinued, retracted, or affected by a security advisory.
    - Fail if current != upgradable (an upgrade is available within existing
      pubspec constraints — typically fixed by `fvm flutter pub upgrade`).
  Transitive packages are ignored.
  Constraint-blocked majors (current == upgradable, but resolvable/latest is
  newer) do not fail: those need intentional pubspec edits and may require
  prereleases or incompatible peers (e.g. share_plus 13 vs file_picker stable).

There is no official pre-commit.com hook for `flutter pub outdated`. The
community `dart_pre_commit` package (pub.dev) has an `outdated` task, but it is
a Dart CLI hooked via custom git scripts—not a pre-commit framework repo—and
would duplicate this project's FVM format/analyze hooks. This local script is
the minimal integration.

Fix typical failures with:
  fvm flutter pub upgrade
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

_RUN_FVM = Path(__file__).resolve().parent / "run_fvm.sh"


def _version(entry: dict | None) -> str | None:
    if entry is None:
        return None
    return entry.get("version")


def _extract_json(raw: str) -> dict:
    start = raw.find("{")
    if start < 0:
        raise ValueError("no JSON object in flutter pub outdated output")
    return json.loads(raw[start:])


def main() -> int:
    try:
        proc = subprocess.run(
            [str(_RUN_FVM), "flutter", "pub", "outdated", "--json"],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print(f"error: {_RUN_FVM} not found or not executable", file=sys.stderr)
        return 1

    if proc.returncode != 0:
        sys.stderr.write(proc.stderr or proc.stdout or "flutter pub outdated failed\n")
        return proc.returncode or 1

    try:
        data = _extract_json(proc.stdout)
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"error: could not parse pub outdated JSON: {exc}", file=sys.stderr)
        return 1

    failures: list[str] = []
    for pkg in data.get("packages", []):
        kind = pkg.get("kind")
        if kind not in ("direct", "dev"):
            continue

        name = pkg.get("package", "<unknown>")
        current = _version(pkg.get("current"))
        upgradable = _version(pkg.get("upgradable"))

        reasons: list[str] = []
        if pkg.get("isDiscontinued"):
            reasons.append("discontinued")
        if pkg.get("isCurrentRetracted"):
            reasons.append("current version retracted")
        if pkg.get("isCurrentAffectedByAdvisory"):
            reasons.append("affected by security advisory")

        if current and upgradable and current != upgradable:
            reasons.append(f"upgradable within constraints {current} -> {upgradable}")

        if reasons:
            label = "dev" if kind == "dev" else "direct"
            failures.append(f"  - {name} ({label}): {', '.join(reasons)}")

    if failures:
        print("Outdated or unsafe direct/dev dependencies:")
        print("\n".join(failures))
        print(
            "\nUpdate with `fvm flutter pub upgrade`. For constraint-blocked majors, "
            "edit pubspec.yaml (e.g. `fvm flutter pub upgrade --major-versions`) "
            "and resolve peer conflicts, then re-run."
        )
        return 1

    print(
        "No upgradable/unsafe direct/dev dependencies "
        "(within current pubspec constraints)."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
