#!/usr/bin/env bash
# Build one prod-release APK for a single ABI.
#
# GitHub Releases and F-Droid must invoke this with the same arguments so the
# APKs can match byte-for-byte. One ABI per process: a combined
# `--split-per-abi` of all ABIs does not produce the same bytes.
#
# Usage:
#   ./scripts/fdroid_build.sh --print-pubspec
#   ./scripts/fdroid_build.sh <android-arm|android-arm64|android-x64>
#   ./scripts/fdroid_build.sh android-arm64 --build-name 0.0.6 --code-base 6
#
# --build-name   Android versionName (default: pubspec versionName)
# --code-base    Base versionCode "+N" from pubspec (default: that N).
#                The APK versionCode is 10 * code-base + ABI offset
#                (armeabi-v7a=1, arm64-v8a=2, x86_64=3).
#
# Requires `flutter` on PATH (CI flutter-action, F-Droid srclib, or
# `./scripts/run_fvm.sh flutter` after exporting PATH). Uses $ROOT/.pub-cache
# unless PUB_CACHE is already set — keep that path identical on GitHub and
# F-Droid for reproducibility.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "error: $*" >&2
  exit 1
}

parse_pubspec_version() {
  local raw
  raw="$(awk '/^version:/ { print $2; exit }' "${ROOT}/pubspec.yaml")"
  raw="${raw%\"}"
  raw="${raw#\"}"
  raw="${raw%\'}"
  raw="${raw#\'}"
  if [[ ! "${raw}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)$ ]]; then
    fail "pubspec.yaml version must look like 1.2.3+4, got: ${raw:-empty}"
  fi
  PUBSPEC_NAME="${BASH_REMATCH[1]}"
  PUBSPEC_CODE="${BASH_REMATCH[2]}"
}

abi_offset() {
  case "$1" in
    android-arm) echo 1 ;;
    android-arm64) echo 2 ;;
    android-x64) echo 3 ;;
    *) fail "unsupported target-platform: $1" ;;
  esac
}

print_pubspec() {
  parse_pubspec_version
  printf 'VERSION_NAME=%s\nCODE_BASE=%s\n' "${PUBSPEC_NAME}" "${PUBSPEC_CODE}"
}

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \?//'
}

if [[ "${1:-}" == "--print-pubspec" ]]; then
  print_pubspec
  exit 0
fi

platform=""
build_name=""
code_base=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    android-arm | android-arm64 | android-x64)
      [[ -z "${platform}" ]] || fail "multiple target platforms given"
      platform="$1"
      shift
      ;;
    --build-name)
      build_name="${2:?--build-name requires a value}"
      shift 2
      ;;
    --code-base)
      code_base="${2:?--code-base requires a value}"
      shift 2
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "${platform}" ]] || fail "target platform required (android-arm, android-arm64, or android-x64)"

parse_pubspec_version
build_name="${build_name:-${PUBSPEC_NAME}}"
code_base="${code_base:-${PUBSPEC_CODE}}"
if [[ ! "${code_base}" =~ ^[0-9]+$ ]]; then
  fail "code-base must be a non-negative integer, got: ${code_base}"
fi

offset="$(abi_offset "${platform}")"
build_number=$((10 * code_base + offset))

command -v flutter >/dev/null 2>&1 || fail "flutter not on PATH"

export PUB_CACHE="${PUB_CACHE:-${ROOT}/.pub-cache}"
cd "${ROOT}"

flutter config --no-analytics
flutter pub get --enforce-lockfile
flutter build apk \
  --release \
  --flavor prod \
  --split-per-abi \
  --target-platform="${platform}" \
  --build-name="${build_name}" \
  --build-number="${build_number}"

echo "Built ${platform} versionName=${build_name} versionCode=${build_number}"
