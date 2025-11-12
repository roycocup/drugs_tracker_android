#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR%/scripts}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Error: flutter CLI not found in PATH." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) not found in PATH." >&2
  exit 1
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <tag> [release-title] [notes]" >&2
  exit 1
fi

TAG="$1"
TITLE="${2:-$TAG}"
NOTES="${3:-"Automated release for $TAG"}"

cd "$REPO_ROOT"

flutter pub get
flutter build apk --release

APK_PATH="$REPO_ROOT/build/app/outputs/flutter-apk/app-release.apk"

if [[ ! -f "$APK_PATH" ]]; then
  echo "Error: APK not found at $APK_PATH" >&2
  exit 1
fi

gh release create "$TAG" "$APK_PATH" \
  --title "$TITLE" \
  --notes "$NOTES"

echo "Release $TAG created with APK asset."


