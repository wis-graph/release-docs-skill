#!/usr/bin/env bash
# 사용법: release.sh <bump_type> [project_root]
# 릴리스 스크립트가 없는 프로젝트용 오케스트레이터.
# 프로젝트 자체 릴리스 스크립트가 있으면 그걸 호출.
set -euo pipefail

BUMP_TYPE="${1:-patch}"
ROOT="${2:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. 프로젝트 감지
eval "$("$SCRIPT_DIR/detect.sh" "$ROOT")"

if [[ -z "$VERSION_FILE" ]]; then
  echo "ERROR: 버전 파일을 찾을 수 없습니다." >&2
  exit 1
fi

# 2. 새 버전 계산
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
case "$BUMP_TYPE" in
  major) NEW_VERSION="$((MAJOR+1)).0.0" ;;
  minor) NEW_VERSION="$MAJOR.$((MINOR+1)).0" ;;
  patch) NEW_VERSION="$MAJOR.$MINOR.$((PATCH+1))" ;;
  *) NEW_VERSION="$BUMP_TYPE" ;;
esac

echo "📦 $CURRENT_VERSION → $NEW_VERSION ($BUMP_TYPE)"

# 3. 프로젝트 자체 릴리스 스크립트가 있으면 위임
if [[ -n "$RELEASE_SCRIPT" ]]; then
  echo "🔗 프로젝트 릴리스 스크립트 발견: $RELEASE_SCRIPT"
  case "$RELEASE_SCRIPT" in
    npm:release)
      cd "$ROOT" && npm run release -- "$BUMP_TYPE"
      ;;
    scripts/release.js)
      cd "$ROOT" && node "$RELEASE_SCRIPT" "$BUMP_TYPE"
      ;;
    scripts/release.sh)
      cd "$ROOT" && bash "$RELEASE_SCRIPT" "$BUMP_TYPE"
      ;;
    scripts/release.py)
      cd "$ROOT" && python3 "$RELEASE_SCRIPT" "$BUMP_TYPE"
      ;;
    make:release)
      cd "$ROOT" && make release VERSION="$NEW_VERSION"
      ;;
  esac
  echo "✅ Released v$NEW_VERSION (via $RELEASE_SCRIPT)"
  exit 0
fi

# 4. 자체 릴리스 스크립트 없음 → 직접 수행
echo "⚙️  릴리스 스크립트 없음 — 직접 수행"

# 4a. 버전 범프
"$SCRIPT_DIR/bump-version.sh" "$ROOT/$VERSION_FILE" "$NEW_VERSION"

# 4b. 빌드 (node 프로젝트만)
if [[ "$ECOSYSTEM" == "node" && -f "$ROOT/package.json" ]] && grep -q '"build"' "$ROOT/package.json"; then
  echo "🔨 Building..."
  cd "$ROOT" && npm run build
fi

# 4c. 커밋 + 태그
cd "$ROOT"
git add -A
git commit -m "chore: release v$NEW_VERSION"
git tag "v$NEW_VERSION"

# 4d. 푸시
echo "🚀 Pushing..."
git push && git push --tags

echo "✅ Released v$NEW_VERSION"
