#!/usr/bin/env bash
# Generate phone-sized PNGs of major Zelp screens into docs/screenshots/.
#
# Uses Flutter widget tests (no emulator / device). Prefer
# ./scripts/run_fvm.sh so worktree GIT_DIR cannot poison the shared SDK.
#
# Usage:
#   ./scripts/generate_screenshots.sh
#   ./scripts/generate_screenshots.sh --name "01 setup"   # one screen
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true

mkdir -p docs/screenshots

# Prefer local Flutter overlay when the shared FVM cache is not writable
# (common in sandboxed agent shells).
if [[ -x "$ROOT/.flutter-sdk/bin/flutter" ]]; then
  export PATH="$ROOT/.flutter-sdk/bin:${PATH:-}"
  export PUB_CACHE="${PUB_CACHE:-$ROOT/.pub-cache}"
  export CI="${CI:-true}"
  FLUTTER=(flutter)
elif [[ -x "$ROOT/scripts/run_fvm.sh" ]] && command -v fvm >/dev/null 2>&1; then
  FLUTTER=("$ROOT/scripts/run_fvm.sh" flutter)
else
  FLUTTER=(flutter)
fi

EXTRA_ARGS=("$@")

"${FLUTTER[@]}" test \
  test/screenshots/generate_screenshots_test.dart \
  --dart-define=GENERATE_SCREENSHOTS=true \
  --update-goldens \
  "${EXTRA_ARGS[@]}"

echo
echo "Screenshots written under docs/screenshots/:"
ls -1 docs/screenshots/*.png
