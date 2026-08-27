#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

SHORT_SHA="$(git rev-parse --short HEAD)"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BUILD_VERSION="${1:-${TIMESTAMP}-${SHORT_SHA}}"

echo "Building web release with version: $BUILD_VERSION"

flutter clean
flutter build web --release --dart-define=APP_BUILD_VERSION="$BUILD_VERSION"

INDEX_FILE="build/web/index.html"
if [[ ! -f "$INDEX_FILE" ]]; then
  echo "Missing $INDEX_FILE"
  exit 1
fi

perl -0pi -e "s/__APP_BUILD_VERSION__/$BUILD_VERSION/g; s/__APP_CACHE_BUSTER__/$BUILD_VERSION/g" "$INDEX_FILE"

printf '%s\n' "$BUILD_VERSION" > build/web/version.txt

echo "Web release ready."
echo "Build version: $BUILD_VERSION"
echo "Artifacts:"
echo "  - build/web"
echo "  - build/web/version.txt"
