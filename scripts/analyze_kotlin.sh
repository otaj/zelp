#!/usr/bin/env bash
# Fast Kotlin static analysis via detekt CLI.
# Prefer this over `./gradlew :app:analyze` in CI/hooks: Gradle boots AGP,
# compiles Flutter's includeBuild plugin, and resolves the full Android
# dependency graph — minutes of work for a sub-second lint of our sources.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Keep in sync with android/settings.gradle.kts (detekt plugin version).
DETEKT_VERSION="${DETEKT_VERSION:-1.23.8}"
CACHE_DIR="${DETEKT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zelp/detekt/${DETEKT_VERSION}}"
CLI_JAR="${CACHE_DIR}/detekt-cli-${DETEKT_VERSION}-all.jar"
FORMATTING_JAR="${CACHE_DIR}/detekt-formatting-${DETEKT_VERSION}.jar"
CONFIG="${ROOT}/android/config/detekt/detekt.yml"
INPUT_DIRS=(
  "${ROOT}/android/app/src/main/kotlin"
  "${ROOT}/android/app/src/main/java"
)

mkdir -p "${CACHE_DIR}"

download() {
  local url="$1"
  local dest="$2"
  if [[ -f "${dest}" ]]; then
    return 0
  fi
  local tmp="${dest}.tmp"
  curl -fsSL --retry 3 --retry-delay 1 -o "${tmp}" "${url}"
  mv "${tmp}" "${dest}"
}

download \
  "https://repo1.maven.org/maven2/io/gitlab/arturbosch/detekt/detekt-cli/${DETEKT_VERSION}/detekt-cli-${DETEKT_VERSION}-all.jar" \
  "${CLI_JAR}"
download \
  "https://repo1.maven.org/maven2/io/gitlab/arturbosch/detekt/detekt-formatting/${DETEKT_VERSION}/detekt-formatting-${DETEKT_VERSION}.jar" \
  "${FORMATTING_JAR}"

inputs=()
for dir in "${INPUT_DIRS[@]}"; do
  if [[ -d "${dir}" ]]; then
    inputs+=("${dir}")
  fi
done
if [[ "${#inputs[@]}" -eq 0 ]]; then
  echo "No Kotlin/Java source directories found under android/app/src/main" >&2
  exit 1
fi

input_csv="$(IFS=,; echo "${inputs[*]}")"

exec java -jar "${CLI_JAR}" \
  --build-upon-default-config \
  --config "${CONFIG}" \
  --plugins "${FORMATTING_JAR}" \
  --input "${input_csv}" \
  --parallel
