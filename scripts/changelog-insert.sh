#!/usr/bin/env bash
# 사용법: echo "entry" | changelog-insert.sh <CHANGELOG경로>
# 또는: changelog-insert.sh <CHANGELOG경로> <엔트리파일>
set -euo pipefail

CHANGELOG="$1"
ENTRY_SOURCE="${2:--}"

if [[ "$ENTRY_SOURCE" == "-" ]]; then
  ENTRY=$(cat)
else
  ENTRY=$(cat "$ENTRY_SOURCE")
fi

if [[ ! -f "$CHANGELOG" ]]; then
  printf "# Changelog\n\n%s\n" "$ENTRY" > "$CHANGELOG"
  echo "CREATED=$CHANGELOG"
else
  # awk -v는 멀티라인 문자열을 처리 못함 → 환경변수 + ENVIRON 사용
  ENTRY="$ENTRY" awk '
    /^## / && !inserted {
      print ENVIRON["ENTRY"]
      print ""
      inserted=1
    }
    { print }
  ' "$CHANGELOG" > "$CHANGELOG.tmp"
  mv "$CHANGELOG.tmp" "$CHANGELOG"
  echo "INSERTED=$CHANGELOG"
fi
