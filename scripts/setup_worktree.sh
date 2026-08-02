#!/usr/bin/env bash
# Bind this worktree to the pinned FVM SDK and resolve pub deps.
#
# Safe to re-run. Does not reinstall the shared SDK if it is already executable.
# See AGENTS.md — run this immediately after `git worktree add`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

RUN_FVM="${ROOT}/scripts/run_fvm.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq not found on PATH (needed to read .fvmrc)" >&2
  exit 1
fi

VERSION="$(jq -r '.flutter // empty' .fvmrc)"
if [[ -z "${VERSION}" || "${VERSION}" == "null" ]]; then
  echo "error: .fvmrc missing flutter version" >&2
  exit 1
fi

CACHE_ROOT="${FVM_CACHE_PATH:-${HOME}/fvm}"
SDK_BIN="${CACHE_ROOT}/versions/${VERSION}/bin/flutter"

if [[ ! -x "${SDK_BIN}" ]]; then
  echo "error: shared FVM SDK is missing or not executable: ${SDK_BIN}" >&2
  echo "Repair once (single process), then re-run this script:" >&2
  echo "  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE" >&2
  echo "  rm -f ${CACHE_ROOT}/cache.git.lock" >&2
  echo "  ${RUN_FVM} install ${VERSION}" >&2
  exit 1
fi

# Creates .fvm/ symlink to the existing cache; does not download again.
"${RUN_FVM}" use --skip-pub-get

# Refuse a half-installed / GIT_DIR-confused SDK.
if ! "${RUN_FVM}" flutter --version 2>/dev/null | grep -q "Flutter ${VERSION}"; then
  echo "error: Flutter SDK at ${CACHE_ROOT}/versions/${VERSION} is not ready" >&2
  echo "Repair once (single process), then re-run this script:" >&2
  echo "  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE" >&2
  echo "  rm -f ${CACHE_ROOT}/cache.git.lock" >&2
  echo "  ${RUN_FVM} install ${VERSION}" >&2
  exit 1
fi

"${RUN_FVM}" flutter pub get
