#!/usr/bin/env bash
# 사용법: release.sh <bump_type> [project_root] [--first-release]
#
# 기본 동작: 프로젝트에 릴리스 인프라(버전 파일/릴리스 스크립트/이전 태그)가 하나도 없으면
#            "릴리스 준비 안 됨"으로 간주하고 **중단**한다. (빈 릴리스 사고 방지)
# --first-release: 첫 릴리스임을 명시적으로 승인. VERSION 파일을 자동 생성하고 릴리스 진행.
#
# 프로젝트 자체 릴리스 스크립트가 있으면 그걸 호출.
set -euo pipefail

# --- 인자 파싱 ---
FIRST_RELEASE="false"
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --first-release) FIRST_RELEASE="true" ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]:-}"

BUMP_TYPE="${1:-patch}"
ROOT="${2:-.}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. 프로젝트 감지
eval "$("$SCRIPT_DIR/detect.sh" "$ROOT")"

# 2. 릴리스 준비도 게이트
if [[ "$RELEASE_READY" != "true" && "$FIRST_RELEASE" != "true" ]]; then
  cat >&2 <<EOF
⚠️  릴리스 준비가 안 된 프로젝트입니다 — 자동 릴리스를 중단합니다.
   감지 결과:
   - VERSION_FILE=${VERSION_FILE:-(없음)}
   - RELEASE_SCRIPT=${RELEASE_SCRIPT:-(없음)}
   - LATEST_TAG=${LATEST_TAG:-(없음)}

   빈 릴리스가 원격에 올라가는 사고를 막기 위해 자동 진행하지 않습니다.

   선택지:
   1) 이 프로젝트의 **첫 릴리스**를 진행하고 싶다면:
      release.sh $BUMP_TYPE "$ROOT" --first-release
   2) 먼저 릴리스 인프라를 세팅하고 싶다면:
      - 버전 파일 수동 생성 (예: echo "0.1.0" > VERSION 또는 package.json/pyproject.toml 등)
      - CHANGELOG.md 초기 템플릿 작성
      - 그 다음 이 스크립트 재실행
EOF
  exit 2
fi

# 3. --first-release 모드: 버전 파일이 없으면 VERSION 생성
if [[ -z "$VERSION_FILE" ]]; then
  if [[ "$FIRST_RELEASE" == "true" ]]; then
    INITIAL_VERSION="${CURRENT_VERSION:-0.1.0}"
    echo "ℹ️  첫 릴리스 — VERSION 파일을 $INITIAL_VERSION 으로 생성합니다."
    echo "$INITIAL_VERSION" > "$ROOT/VERSION"
    VERSION_FILE="VERSION"
    ECOSYSTEM="generic"
    CURRENT_VERSION="$INITIAL_VERSION"
    # 첫 릴리스는 초기 버전을 그대로 사용 (범프 생략)
    NEW_VERSION="$INITIAL_VERSION"
  else
    # 준비도 게이트를 통과한 경우 (LATEST_TAG 또는 RELEASE_SCRIPT가 있을 때)
    # 버전 파일은 없지만 태그/스크립트가 있으므로 위임 또는 태그 기반 진행
    echo "ℹ️  버전 파일은 없지만 릴리스 히스토리/스크립트가 있어 계속 진행합니다."
  fi
fi

# 4. 현재 버전 보정
if [[ -z "$CURRENT_VERSION" ]]; then
  CURRENT_VERSION="0.0.0"
fi

# 5. 새 버전 계산 (NEW_VERSION이 이미 설정되어 있지 않으면)
if [[ -z "${NEW_VERSION:-}" ]]; then
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
  MAJOR="${MAJOR:-0}"
  MINOR="${MINOR:-0}"
  PATCH="${PATCH:-0}"
  case "$BUMP_TYPE" in
    major) NEW_VERSION="$((MAJOR+1)).0.0" ;;
    minor) NEW_VERSION="$MAJOR.$((MINOR+1)).0" ;;
    patch) NEW_VERSION="$MAJOR.$MINOR.$((PATCH+1))" ;;
    *) NEW_VERSION="$BUMP_TYPE" ;;
  esac
fi

echo "📦 $CURRENT_VERSION → $NEW_VERSION ($BUMP_TYPE)"

# 6. 프로젝트 자체 릴리스 스크립트가 있으면 위임
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

# 7. 자체 릴리스 스크립트 없음 → 직접 수행
echo "⚙️  릴리스 스크립트 없음 — 직접 수행"

# 7a. 버전 범프 (첫 릴리스면 이미 VERSION 파일을 초기값으로 생성했으므로 건너뜀)
if [[ "$FIRST_RELEASE" == "true" && -f "$ROOT/$VERSION_FILE" ]]; then
  : # 이미 초기값 기록됨
elif [[ -n "$VERSION_FILE" ]]; then
  "$SCRIPT_DIR/bump-version.sh" "$ROOT/$VERSION_FILE" "$NEW_VERSION"
fi

# 7b. 빌드 (node 프로젝트만)
if [[ "$ECOSYSTEM" == "node" && -f "$ROOT/package.json" ]] && grep -q '"build"' "$ROOT/package.json"; then
  echo "🔨 Building..."
  cd "$ROOT" && npm run build
fi

# 7c. 커밋 + 태그
cd "$ROOT"
git add -A
git commit -m "chore: release v$NEW_VERSION"
git tag "v$NEW_VERSION"

# 7d. 푸시 (원격이 있을 때만)
if git remote | grep -q .; then
  echo "🚀 Pushing..."
  git push && git push --tags
else
  echo "ℹ️  원격 저장소 없음 — 푸시 건너뜀 (로컬 커밋/태그만 생성)"
fi

echo "✅ Released v$NEW_VERSION"
