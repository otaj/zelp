#!/usr/bin/env bash
# Fail if proprietary Google libraries / Play dependency metadata are present.
#
# Layer A — Gradle prodReleaseRuntimeClasspath must not resolve:
#   com.google.android.gms, com.google.firebase, com.google.mlkit,
#   com.google.android.play (Play feature/core delivery SDKs).
# Open-source Google Maven artifacts (Tink, Gson, Guava stubs, annotations)
# are allowed. With product flavors, AGP names the config
# {flavor}{BuildType}RuntimeClasspath (prod + release → prodRelease…).
#
# Layer B — optional APK paths must not contain Play's encrypted
# "Dependency metadata" signing block (id 0x504b4453 / "PKDS").
#
# Usage:
#   ./scripts/check_no_google_libs.sh
#   ./scripts/check_no_google_libs.sh path/to/app-release.apk [...]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Match the release / README `--flavor prod` build.
GRADLE_CONFIGURATION="${GRADLE_CONFIGURATION:-prodReleaseRuntimeClasspath}"
# APK Signing Block id for AGP "Dependency metadata" (Play SDK dependency info).
DEPENDENCY_METADATA_BLOCK_ID=$((0x504b4453))

FORBIDDEN_GRADLE_REGEX='com\.google\.android\.gms|com\.google\.firebase|com\.google\.mlkit|com\.google\.android\.play'

fail() {
  echo "error: $*" >&2
  exit 1
}

check_gradle_classpath() {
  echo "==> Checking ${GRADLE_CONFIGURATION} for proprietary Google libraries"
  local deps
  deps="$(
    cd "${ROOT}/android"
    # Keep Gradle log noise down; the dependencies report still goes to stdout.
    ./gradlew --quiet :app:dependencies --configuration "${GRADLE_CONFIGURATION}"
  )"
  local hits
  hits="$(printf '%s\n' "${deps}" | grep -E "${FORBIDDEN_GRADLE_REGEX}" || true)"
  if [[ -n "${hits}" ]]; then
    echo "${hits}" >&2
    fail "proprietary Google libraries found on ${GRADLE_CONFIGURATION}"
  fi
  echo "    OK — no GMS / Firebase / ML Kit / Play libraries"
}

# Parse APK Signing Block pair IDs between the ZIP central directory and EOCD.
# See https://source.android.com/docs/security/features/apksigning/v2
apk_signing_block_ids() {
  local apk="$1"
  python3 - "$apk" <<'PY'
import struct, sys

path = sys.argv[1]
with open(path, "rb") as f:
    data = f.read()

eocd_magic = b"PK\x05\x06"
pos = data.rfind(eocd_magic)
if pos < 0:
    sys.stderr.write("no ZIP EOCD found\n")
    sys.exit(2)
if pos + 22 > len(data):
    sys.stderr.write("truncated EOCD\n")
    sys.exit(2)
cd_offset = struct.unpack_from("<I", data, pos + 16)[0]
if cd_offset < 32 or cd_offset > len(data):
    sys.stderr.write("invalid central-directory offset\n")
    sys.exit(2)

# Footer immediately before CD: size(8) + magic(16)
footer_start = cd_offset - 24
if footer_start < 0:
    # Unsigned / v1-only APK — no signing block pairs.
    sys.exit(0)
magic = data[footer_start + 8 : footer_start + 24]
if magic != b"APK Sig Block 42":
    sys.exit(0)

block_size = struct.unpack_from("<Q", data, footer_start)[0]
block_start = cd_offset - block_size - 8
if block_start < 0 or block_start + 8 > footer_start:
    sys.stderr.write("invalid APK Signing Block bounds\n")
    sys.exit(2)

# Leading size field must match trailing size.
leading_size = struct.unpack_from("<Q", data, block_start)[0]
if leading_size != block_size:
    sys.stderr.write("APK Signing Block size mismatch\n")
    sys.exit(2)

pairs_start = block_start + 8
pairs_end = footer_start
offset = pairs_start
ids = []
while offset + 8 <= pairs_end:
    pair_len = struct.unpack_from("<Q", data, offset)[0]
    offset += 8
    if pair_len < 4 or offset + pair_len > pairs_end:
        sys.stderr.write("invalid signing-block pair length\n")
        sys.exit(2)
    pair_id = struct.unpack_from("<I", data, offset)[0]
    ids.append(pair_id)
    offset += pair_len

for pair_id in ids:
    print(f"0x{pair_id:08x}")
PY
}

check_apk() {
  local apk="$1"
  echo "==> Checking APK ${apk}"
  [[ -f "${apk}" ]] || fail "APK not found: ${apk}"

  local ids
  ids="$(apk_signing_block_ids "${apk}")" || fail "failed to parse APK signing block: ${apk}"
  if printf '%s\n' "${ids}" | grep -qx "0x$(printf '%08x' "${DEPENDENCY_METADATA_BLOCK_ID}")"; then
    fail "APK contains Google Play Dependency metadata signing block (0x504b4453): ${apk}"
  fi
  echo "    OK — no Dependency metadata signing block"

  # Belt-and-braces: proprietary class descriptors should not appear in DEX.
  local dex_hits
  dex_hits="$(
    python3 - "${apk}" <<'PY'
import sys, zipfile
apk = sys.argv[1]
needles = (
    b"Lcom/google/android/gms/",
    b"Lcom/google/firebase/",
    b"Lcom/google/mlkit/",
    b"Lcom/google/android/play/",
)
found = []
with zipfile.ZipFile(apk) as zf:
    for name in zf.namelist():
        if not (name == "classes.dex" or (name.startswith("classes") and name.endswith(".dex"))):
            continue
        data = zf.read(name)
        for needle in needles:
            if needle in data:
                found.append(needle.decode("ascii"))
if found:
    print("\n".join(dict.fromkeys(found)))
    sys.exit(0)
PY
  )"
  if [[ -n "${dex_hits}" ]]; then
    echo "${dex_hits}" >&2
    fail "proprietary Google class descriptors found in DEX: ${apk}"
  fi
  echo "    OK — no proprietary Google class descriptors in DEX"
}

check_gradle_classpath

if [[ "$#" -gt 0 ]]; then
  for apk in "$@"; do
    check_apk "${apk}"
  done
else
  echo "==> No APK arguments; skipped signing-block / DEX checks"
fi

echo "All Google-library checks passed."
