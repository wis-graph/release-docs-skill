#!/usr/bin/env bash
# 프로젝트 루트에서 실행. 버전 파일, 릴리스 스크립트, CHANGELOG, docs 디렉터리를 감지.
# 출력: key=value 형식 (source로 읽기 가능)
set -euo pipefail
ROOT="${1:-.}"

# --- 버전 파일 ---
VERSION_FILE=""
CURRENT_VERSION=""
ECOSYSTEM=""

if [[ -f "$ROOT/package.json" ]]; then
  VERSION_FILE="package.json"
  CURRENT_VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$ROOT/package.json" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//' | sed 's/"//')
  ECOSYSTEM="node"
elif [[ -f "$ROOT/pyproject.toml" ]]; then
  VERSION_FILE="pyproject.toml"
  CURRENT_VERSION=$(grep -E '^version[[:space:]]*=' "$ROOT/pyproject.toml" | head -1 | sed 's/.*=[[:space:]]*//' | tr -d "\"'")
  ECOSYSTEM="python"
elif [[ -f "$ROOT/Cargo.toml" ]]; then
  VERSION_FILE="Cargo.toml"
  CURRENT_VERSION=$(grep -E '^version[[:space:]]*=' "$ROOT/Cargo.toml" | head -1 | sed 's/.*=[[:space:]]*//' | tr -d "\"'")
  ECOSYSTEM="rust"
elif [[ -f "$ROOT/VERSION" ]]; then
  VERSION_FILE="VERSION"
  CURRENT_VERSION=$(cat "$ROOT/VERSION" | tr -d '[:space:]')
  ECOSYSTEM="generic"
fi

# --- 릴리스 스크립트 ---
RELEASE_SCRIPT=""
if [[ -f "$ROOT/package.json" ]] && grep -q '"release"' "$ROOT/package.json"; then
  RELEASE_SCRIPT="npm:release"
elif [[ -f "$ROOT/scripts/release.js" ]]; then
  RELEASE_SCRIPT="scripts/release.js"
elif [[ -f "$ROOT/scripts/release.sh" ]]; then
  RELEASE_SCRIPT="scripts/release.sh"
elif [[ -f "$ROOT/scripts/release.py" ]]; then
  RELEASE_SCRIPT="scripts/release.py"
elif [[ -f "$ROOT/Makefile" ]] && grep -q '^release:' "$ROOT/Makefile"; then
  RELEASE_SCRIPT="make:release"
fi

# --- CHANGELOG ---
CHANGELOG=""
for f in CHANGELOG.md docs/CHANGELOG.md CHANGES.md HISTORY.md; do
  if [[ -f "$ROOT/$f" ]]; then
    CHANGELOG="$f"
    break
  fi
done

# --- docs 디렉터리 ---
DOCS_DIR=""
for d in docs/guide docs wiki; do
  if [[ -d "$ROOT/$d" ]]; then
    DOCS_DIR="$d"
    break
  fi
done

# --- git 태그 fallback ---
# 버전 파일이 없어도 git 태그에서 현재 버전을 추론할 수 있음
LATEST_TAG=""
if [[ -d "$ROOT/.git" ]] || git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  LATEST_TAG=$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || true)
fi

# 버전 파일이 없지만 git 태그가 있으면 거기서 버전 추출
if [[ -z "$CURRENT_VERSION" && -n "$LATEST_TAG" ]]; then
  CURRENT_VERSION="${LATEST_TAG#v}"
fi

# --- 릴리스 준비도 ---
# 버전 파일, 릴리스 스크립트, 이전 태그 중 하나라도 있으면 "준비됨"으로 간주.
# 셋 다 없으면 의도치 않은 릴리스를 막기 위해 RELEASE_READY=false
RELEASE_READY="false"
if [[ -n "$VERSION_FILE" || -n "$RELEASE_SCRIPT" || -n "$LATEST_TAG" ]]; then
  RELEASE_READY="true"
fi

# --- 출력 ---
cat <<DETECT
VERSION_FILE=$VERSION_FILE
CURRENT_VERSION=$CURRENT_VERSION
ECOSYSTEM=$ECOSYSTEM
RELEASE_SCRIPT=$RELEASE_SCRIPT
CHANGELOG=$CHANGELOG
DOCS_DIR=$DOCS_DIR
LATEST_TAG=$LATEST_TAG
RELEASE_READY=$RELEASE_READY
DETECT
