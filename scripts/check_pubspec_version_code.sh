#!/usr/bin/env bash
# Fail unless pubspec.yaml version is X.Y.Z+N with
# N = 10000*major + 100*minor + patch (pre-ABI Android versionCode).
#
# Usage:
#   ./scripts/check_pubspec_version_code.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "error: $*" >&2
  exit 1
}

raw="$(awk '/^version:/ { print $2; exit }' "${ROOT}/pubspec.yaml")"
raw="${raw%\"}"
raw="${raw#\"}"
raw="${raw%\'}"
raw="${raw#\'}"

if [[ ! "${raw}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
  fail "pubspec.yaml version must look like 1.2.3+N, got: ${raw:-empty}"
fi

major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"
code="${BASH_REMATCH[4]}"
expected=$((10#${major} * 10000 + 10#${minor} * 100 + 10#${patch}))

if ((10#${code} != expected)); then
  fail "pubspec.yaml versionCode +${code} must equal 10000*${major} + 100*${minor} + ${patch} (=${expected})"
fi

echo "pubspec.yaml version ${raw} matches 10000*${major} + 100*${minor} + ${patch}"
