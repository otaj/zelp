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
#   ./scripts/fdroid_build.sh android-arm64 --build-name 0.0.6 --version-code-base 6
#
# --build-name          Android versionName (default: pubspec X.Y.Z)
# --version-code-base   Pre-ABI versionCode passed as --build-number (default:
#                       pubspec +N). ABI packing lives only in
#                       android/app/build.gradle.kts (10*N + ABI).
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
  if [[ ! "${raw}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)$ ]]; then
    fail "pubspec.yaml version must look like 1.2.3+N, got: ${raw:-empty}"
  fi
  PUBSPEC_NAME="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  PUBSPEC_CODE="${BASH_REMATCH[4]}"
}

print_pubspec() {
  parse_pubspec_version
  printf 'VERSION_NAME=%s\nVERSION_CODE_BASE=%s\n' "${PUBSPEC_NAME}" "${PUBSPEC_CODE}"
}

usage() {
  sed -n '2,21p' "$0" | sed 's/^# \?//'
}

if [[ "${1:-}" == "--print-pubspec" ]]; then
  print_pubspec
  exit 0
fi

platform=""
build_name=""
version_code_base=""
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
    --version-code-base)
      version_code_base="${2:?--version-code-base requires a value}"
      shift 2
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -n "${platform}" ]] || fail "target platform required (android-arm, android-arm64, or android-x64)"

parse_pubspec_version
if [[ -n "${version_code_base}" && ! "${version_code_base}" =~ ^[0-9]+$ ]]; then
  fail "version-code-base must be a non-negative integer, got: ${version_code_base}"
fi

command -v flutter >/dev/null 2>&1 || fail "flutter not on PATH"

export PUB_CACHE="${PUB_CACHE:-${ROOT}/.pub-cache}"
cd "${ROOT}"

flutter_args=(
  build
  apk
  --release
  --flavor
  prod
  --split-per-abi
  --target-platform="${platform}"
)
if [[ -n "${build_name}" ]]; then
  flutter_args+=(--build-name="${build_name}")
fi
if [[ -n "${version_code_base}" ]]; then
  flutter_args+=(--build-number="${version_code_base}")
fi

flutter config --no-analytics
flutter pub get --enforce-lockfile
# TODO: Remove once Flutter's libdartjni.so no longer embeds a non-reproducible
# build ID. Same patch as Obtainium (ImranR98/Obtainium#2977). Idempotent so
# the per-ABI loop does not stack --build-id=none.
shopt -s nullglob
jni_cmakes=("${PUB_CACHE}/hosted/"*/jni-*/src/CMakeLists.txt)
shopt -u nullglob
if [[ ${#jni_cmakes[@]} -eq 0 ]]; then
  fail "jni CMakeLists.txt not found under PUB_CACHE=${PUB_CACHE} (needed to strip libdartjni.so build ID)"
fi
sed -i -E 's/-Wl,(--build-id=none,)?/-Wl,--build-id=none,/' "${jni_cmakes[@]}"
flutter "${flutter_args[@]}"

echo "Built ${platform} versionName=${build_name:-${PUBSPEC_NAME}} pre-ABI versionCode=${version_code_base:-${PUBSPEC_CODE}} PUB_CACHE=${PUB_CACHE}"
