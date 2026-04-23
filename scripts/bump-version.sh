#!/usr/bin/env bash
# 사용법: bump-version.sh <버전파일> <새버전>
set -euo pipefail

FILE="$1"
NEW_VERSION="$2"
BASENAME=$(basename "$FILE")

case "$BASENAME" in
  package.json)
    sed -i '' "s/\"version\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"version\": \"$NEW_VERSION\"/" "$FILE"
    ;;
  pyproject.toml|Cargo.toml)
    sed -i '' "s/^version[[:space:]]*=.*/version = \"$NEW_VERSION\"/" "$FILE"
    ;;
  VERSION)
    echo "$NEW_VERSION" > "$FILE"
    ;;
  build.gradle|build.gradle.kts)
    sed -i '' "s/version[[:space:]]*=[[:space:]]*['\"][^'\"]*['\"]/version = '$NEW_VERSION'/" "$FILE"
    ;;
  *)
    echo "ERROR: Unknown version file: $FILE" >&2
    exit 1
    ;;
esac

echo "BUMPED=$FILE:$NEW_VERSION"
