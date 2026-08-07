#!/usr/bin/env bash
# Capture on-device Zelp screenshots into docs/screenshots/.
#
# Requires:
#   - An Android device or emulator (`adb devices`)
#   - `.env` with at least ZEPP_EMAIL and ZEPP_PASSWORD (see `.env.example`)
#
# Installs the `screenshots` flavor (`org.zelp.screenshots` / “Zelp Screenshots”)
# so it can sit beside a normal Zelp debug/release build.
# Usage:
#   cp .env.example .env   # then edit credentials
#   ./scripts/capture_screenshots.sh
#   ./scripts/capture_screenshots.sh --keep-data   # skip `pm clear`
#
# Prefer ./scripts/run_fvm.sh so worktree GIT_DIR cannot poison the shared SDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR || true

KEEP_DATA=0
EXTRA_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --keep-data) KEEP_DATA=1 ;;
    *) EXTRA_ARGS+=("$arg") ;;
  esac
done

if [[ ! -f .env ]]; then
  echo "Missing .env — copy .env.example and set ZEPP_EMAIL / ZEPP_PASSWORD." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

: "${ZEPP_EMAIL:?Set ZEPP_EMAIL in .env}"
: "${ZEPP_PASSWORD:?Set ZEPP_PASSWORD in .env}"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found on PATH" >&2
  exit 1
fi

mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if ((${#DEVICES[@]} == 0)); then
  echo "No Android device/emulator online. Connect one and retry." >&2
  exit 1
fi

DEVICE="${ZELP_DEVICE_ID:-}"
if [[ -z "$DEVICE" ]]; then
  if ((${#DEVICES[@]} == 1)); then
    DEVICE="${DEVICES[0]}"
  else
    echo "Multiple devices attached; set ZELP_DEVICE_ID in .env:" >&2
    printf '  %s\n' "${DEVICES[@]}" >&2
    exit 1
  fi
fi

FLUTTER=("$ROOT/scripts/run_fvm.sh" flutter)

mkdir -p docs/screenshots

DEFINES_FILE="$(mktemp "${TMPDIR:-/tmp}/zelp-screenshot-defines.XXXXXX.json")"
WATCHER_PID=""
# shellcheck disable=SC2329 # invoked via trap EXIT
cleanup() {
  rm -f "$DEFINES_FILE"
  if [[ -n "${WATCHER_PID}" ]] && kill -0 "$WATCHER_PID" 2>/dev/null; then
    kill "$WATCHER_PID" 2>/dev/null || true
    wait "$WATCHER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# JSON dart-define file so passwords with special characters stay intact.
python3 - "$DEFINES_FILE" <<'PY'
import json, os, sys

path = sys.argv[1]
data = {
    "ZEPP_EMAIL": os.environ["ZEPP_EMAIL"],
    "ZEPP_PASSWORD": os.environ["ZEPP_PASSWORD"],
}
for key in (
    "ZELP_WATCH_NAME",
    "ZELP_FETCH_KEYS",
    "ZELP_REFRESH_CATALOG",
    "ZELP_CHECK_FIRMWARE",
):
    value = os.environ.get(key)
    if value is not None and value != "":
        data[key] = value

with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh)
PY

APP_ID=org.zelp.screenshots
IPC_REL="app_flutter/screenshot_ipc"

if [[ "$KEEP_DATA" -eq 0 ]]; then
  echo "Clearing $APP_ID on $DEVICE for a clean first-run setup…"
  adb -s "$DEVICE" shell pm clear "$APP_ID" >/dev/null 2>&1 || true
fi

# Poll for screenshot requests written by the integration test and capture with
# adb screencap (true on-device frames, including system chrome).
(
  last=""
  while true; do
    name="$(
      adb -s "$DEVICE" shell "run-as $APP_ID cat $IPC_REL/request 2>/dev/null" \
        | tr -d '\r\n' || true
    )"
    if [[ -n "$name" && "$name" != "$last" ]]; then
      out="$ROOT/docs/screenshots/${name}.png"
      if adb -s "$DEVICE" exec-out screencap -p >"$out" && [[ -s "$out" ]]; then
        echo "Wrote $out ($(wc -c <"$out") bytes)"
        adb -s "$DEVICE" shell "run-as $APP_ID sh -c 'rm -f $IPC_REL/request; echo ok > $IPC_REL/done'" >/dev/null
        last="$name"
      fi
    fi
    sleep 0.25
  done
) &
WATCHER_PID=$!

echo "Capturing screenshots on $DEVICE…"
# Keep the display awake so long catalog refreshes do not suspend the app.
adb -s "$DEVICE" shell svc power stayon true >/dev/null 2>&1 || true
adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1 || true
set +e
"${FLUTTER[@]}" drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshots_test.dart \
  --flavor screenshots \
  -d "$DEVICE" \
  --dart-define-from-file="$DEFINES_FILE" \
  "${EXTRA_ARGS[@]}"
STATUS=$?
set -e
adb -s "$DEVICE" shell svc power stayon false >/dev/null 2>&1 || true

echo
echo "Screenshots under docs/screenshots/:"
ls -1 docs/screenshots/*.png 2>/dev/null || echo "(none found — check drive output)"
exit "$STATUS"
