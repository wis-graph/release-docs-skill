# release-docs 동작 원리

## 핵심 아이디어

릴리스에는 두 종류의 작업이 있다:

| 종류 | 예시 | 누가 잘하나 |
|------|------|------------|
| **판단이 필요한 작업** | "이번 변경을 사용자에게 어떻게 설명할까?" | LLM |
| **기계적인 작업** | 버전 파일 수정, git 커밋, 태그, 푸시 | 스크립트 |

release-docs는 이 둘을 분리한다. LLM은 CHANGELOG 텍스트 생성만 하고, 나머지는 스크립트가 처리한다. 이렇게 하면 **토큰을 절약**하면서도 **사람이 쓴 것 같은 CHANGELOG**를 얻는다.

---

## 전체 흐름

```
사용자: "릴리스해줘"
        │
        ▼
┌─── 훅 (자동) ───────────────────────────────┐
│  UserPromptSubmit 훅이 "릴리스" 키워드 감지   │
│  → detect.sh 자동 실행                       │
│  → 프로젝트 정보가 LLM 컨텍스트에 주입됨      │
└──────────────────────────────────────────────┘
        │
        ▼
┌─── LLM (판단) ──────────────────────────────┐
│  1. detect 결과 읽기                         │
│     "이 프로젝트는 Python이고,               │
│      pyproject.toml에 버전 1.2.3이 있고,     │
│      릴리스 스크립트는 없구나"                 │
│                                              │
│  2. 세션 컨텍스트에서 변경 분류               │
│     "이번에 버그 2개 고치고 기능 1개 추가했지" │
│                                              │
│  3. 버전 범프 결정                           │
│     "새 기능이 있으니 minor → 1.3.0"         │
│                                              │
│  4. CHANGELOG 텍스트 생성                    │
│     기존 포맷에 맞춰, 사용자 관점으로 작성     │
└──────────────────────────────────────────────┘
        │
        ▼
┌─── 스크립트 (실행) ─────────────────────────┐
│  5. changelog-insert.sh                     │
│     → CHANGELOG.md에 새 항목 삽입            │
│                                              │
│  6. release.sh minor                        │
│     → 프로젝트 자체 스크립트가 있으면 위임     │
│     → 없으면 직접: 버전 범프 → 빌드 →        │
│       커밋 → 태그 → 푸시                     │
└──────────────────────────────────────────────┘
        │
        ▼
    릴리스 완료 ✅
```

---

## 구성 요소

### 1. 훅 (`hooks/hooks.json`)

```
트리거: 사용자 메시지에 "릴리스" 또는 "release" 포함
동작: detect.sh를 자동 실행하여 결과를 LLM 컨텍스트에 주입
```

사용자가 "릴리스해줘"라고 말하면, LLM이 응답하기 **전에** 훅이 먼저 동작한다. LLM은 이미 프로젝트 정보를 알고 있는 상태에서 시작하므로 탐색에 토큰을 쓰지 않는다.

### 2. 감지 스크립트 (`scripts/detect.sh`)

프로젝트 루트를 스캔하여 8가지 정보를 key=value로 출력한다:

```bash
$ bash scripts/detect.sh /path/to/project

VERSION_FILE=pyproject.toml      # 버전이 기록된 파일 (없으면 빈값)
CURRENT_VERSION=1.2.3            # 현재 버전 (버전 파일 없으면 git 태그에서 추론)
ECOSYSTEM=python                 # 에코시스템 (node/python/rust/generic)
RELEASE_SCRIPT=                  # 프로젝트 자체 릴리스 스크립트 (없으면 빈값)
CHANGELOG=CHANGELOG.md           # CHANGELOG 파일 위치 (없으면 빈값)
DOCS_DIR=                        # 기능 문서 디렉터리 (없으면 빈값)
LATEST_TAG=v1.2.3                # 최신 git 태그 (없으면 빈값)
RELEASE_READY=true               # VERSION_FILE/RELEASE_SCRIPT/LATEST_TAG 중 하나라도 있으면 true
```

`RELEASE_READY=false`는 "릴리스 인프라가 하나도 없는 프로젝트"를 의미한다. 이 경우 `release.sh`는 의도치 않은 빈 릴리스를 막기 위해 자동 진행을 중단한다 (아래 "릴리스 준비도 게이트" 참조).

**감지 우선순위:**

| 순서 | 버전 파일 | 에코시스템 |
|:----:|----------|-----------|
| 1 | `package.json` | Node.js |
| 2 | `pyproject.toml` | Python |
| 3 | `Cargo.toml` | Rust |
| 4 | `VERSION` | 범용 |

프로젝트에 릴리스 스크립트가 있는지도 탐색한다:
- `package.json`의 `"release"` 스크립트
- `scripts/release.js`, `release.sh`, `release.py`
- `Makefile`의 `release:` 타겟

### 3. SKILL.md — LLM 워크플로우

LLM이 따르는 지시문이다. **기계적 작업은 포함하지 않고**, LLM만 할 수 있는 판단 작업을 안내한다:

- 세션에서 한 작업을 분류 (새 기능 / 버그 수정 / 개선 / 내부)
- 버전 범프 결정 (breaking → major, feature → minor, fix → patch)
- CHANGELOG 텍스트를 **사용자 관점**으로 생성
- 기능 문서 업데이트 필요 여부 판단

**핵심 원칙:**
- 사용자에게 묻지 않는다 (버전, 진행 여부 등)
- 커밋 메시지가 아닌 세션 컨텍스트를 사용한다
- 함수명/파일명 등 내부 구현을 CHANGELOG에 노출하지 않는다

### 4. 실행 스크립트

| 스크립트 | 하는 일 | 입력 | 출력 |
|---------|---------|------|------|
| `detect.sh` | 프로젝트 구조 감지 | 프로젝트 경로 | key=value 6개 |
| `bump-version.sh` | 버전 파일 수정 | 파일 경로 + 새 버전 | 수정된 파일 |
| `changelog-insert.sh` | CHANGELOG에 항목 삽입 | CHANGELOG 경로 + stdin 텍스트 | 수정된 CHANGELOG |
| `release.sh` | 전체 릴리스 오케스트레이션 | 범프 타입 + 프로젝트 경로 | 커밋 + 태그 + 푸시 |

---

## 프로젝트 자체 릴리스 스크립트가 있을 때

많은 프로젝트에 이미 릴리스 스크립트가 있다 (예: `scripts/release.js`). 이 경우 release-docs는 **중복 작업을 하지 않는다**.

```
detect.sh → RELEASE_SCRIPT=scripts/release.js 발견
                │
                ▼
        LLM이 release.js를 읽음
        "이 스크립트는 버전 범프 + 빌드 + 커밋 + 태그 + 푸시를 다 하는구나"
                │
                ▼
        LLM은 CHANGELOG만 수정
        (커밋/태그/푸시/버전범프 직접 안 함)
                │
                ▼
        release.sh → release.js에 위임
        "node scripts/release.js patch"
```

이렇게 하면 **이중 커밋**, **이중 버전 범프** 같은 문제가 발생하지 않는다.

---

## 릴리스 스크립트가 없을 때

스크립트 없는 프로젝트에서는 release-docs가 직접 모든 단계를 수행한다:

```
1. bump-version.sh  → pyproject.toml 버전 수정
2. npm run build    → (빌드 스크립트가 있으면)
3. git add -A
4. git commit -m "chore: release v1.3.0"
5. git tag v1.3.0
6. git push && git push --tags  → (원격 저장소가 있으면)
```

## 릴리스 준비도 게이트 (중요)

버전 파일도, 릴리스 스크립트도, 이전 태그도 없는 "맨땅" 프로젝트에서 자동 릴리스를 돌리면 원격에 의도치 않은 빈 릴리스가 올라간다. 이걸 막기 위해 `release.sh`는 **준비도 게이트**를 둔다.

```
detect.sh 출력:
  VERSION_FILE=, RELEASE_SCRIPT=, LATEST_TAG=  → RELEASE_READY=false
        │
        ▼
release.sh (플래그 없이 실행):
  exit 2 — "릴리스 준비 안 됨" 메시지 + 안내 출력
        │
        ▼
LLM이 사용자에게 확인:
  "릴리스 인프라가 없어 자동 진행을 멈췄습니다.
   1) 첫 릴리스로 진행 (v0.1.0 생성)
   2) 취소 — 먼저 세팅할게요"
        │
        ├──── 1 선택 ────▶ release.sh $BUMP . --first-release
        │                    - VERSION 파일 0.1.0 생성
        │                    - bump-version.sh로 범프
        │                    - changelog-insert.sh가 CHANGELOG.md 생성
        │                    - git commit + tag + (원격 있으면) push
        │
        └──── 2 선택 ────▶ 중단 (사용자가 직접 세팅)
```

**핵심:** "릴리스 인프라가 없음"은 자동 진행의 신호가 아니라 **사용자 확인이 필요한 신호**다. 한 번 세팅된 후(태그든 버전 파일이든 생기면)부터는 `RELEASE_READY=true`가 되어 평소처럼 자동 진행된다.

### 준비된 프로젝트 (`RELEASE_READY=true`)

버전 파일 OR 릴리스 스크립트 OR 이전 태그 중 하나라도 있으면 "준비됨"으로 간주. 평소처럼 `release.sh <bump>`만 호출하면 끝:

```
1. bump-version.sh  → 버전 파일 수정 (있을 때만)
2. npm run build    → (빌드 스크립트가 있으면)
3. git add -A
4. git commit -m "chore: release vX.Y.Z"
5. git tag vX.Y.Z
6. git push && git push --tags  → (원격 저장소가 있으면)
```

---

## CHANGELOG 작성 방식

### 왜 LLM이 쓰나?

| 방식 | CHANGELOG 품질 | 문제점 |
|------|---------------|--------|
| 커밋 메시지 기반 | "fix: patch auth bug" | 개발자 용어, 사용자가 이해 못함 |
| 수동 작성 | 높음 | 매번 사람이 써야 함 |
| **LLM 세션 컨텍스트 기반** | 높음 | 자동 |

LLM은 세션 중에 무엇을 했는지 알고 있다. "auth 토큰 refresh 로직에서 expiry 체크 순서를 바꿨다"는 내부 사실을 "로그인 상태가 갑자기 풀리는 문제를 수정했습니다"라는 **사용자 언어**로 번역할 수 있다.

### 기존 포맷 준수

CHANGELOG가 이미 있으면 그 포맷을 따른다:

```markdown
# 이 프로젝트의 기존 CHANGELOG가 이런 포맷이면:
## v0.10.13 (2026-04-13)
### 버그 수정
- **YouTube 저장 후 편집 불가 수정**: 설명...

# LLM도 같은 포맷으로 작성:
## v0.10.14 (2026-04-23)
### 새 기능
- **격자 스냅**: 도형 이동 시 격자에 맞춰 정렬...
```

새 프로젝트면 프로젝트의 주 언어/문화권에 맞춰 생성한다.

---

## 플랫폼별 동작 차이

### Claude Code (프로젝트 로컬 — 권장)

```
.claude/settings.json의 훅 정의 → detect.sh 자동 실행 → 스킬 로드 → 스크립트 호출
```

프로젝트 루트에 클론된 `.release-docs/`를 `$CLAUDE_PROJECT_DIR` 기준으로 참조한다. 해당 프로젝트에서만 훅이 작동하고 다른 프로젝트는 영향받지 않는다.

### Claude Code (글로벌 마켓플레이스)

```
플러그인 훅 자동 감지 → 스킬 로드 → ${CLAUDE_PLUGIN_ROOT}/scripts 호출
```

모든 프로젝트에서 훅이 활성화된다. 개인용으로 쓰기 편하지만 팀원과 공유하기는 어렵다.

### Codex / Gemini CLI

```
AGENTS.md 또는 GEMINI.md 읽기 → 스크립트 호출
```

훅이 없어서 LLM이 직접 detect.sh를 실행해야 한다. 하지만 워크플로우와 스크립트는 동일하게 동작한다.

### Cursor / Windsurf 등

```
규칙 파일에 SKILL.md 내용 포함 → 스크립트 호출
```

스킬 시스템이 없으므로 규칙 파일에 직접 넣어야 한다. 스크립트는 동일하게 사용 가능.

---

## 토큰 절약 효과

| 구성 | 토큰 사용 |
|------|----------|
| 스킬만 (스크립트 없음) | LLM이 감지+판단+실행 전부 = **높음** |
| **스크립트 + 스킬** | LLM은 판단만, 나머지 스크립트 = **낮음** |

detect.sh가 6줄의 key=value를 출력하는 것과, LLM이 직접 파일을 열어보며 "이건 package.json이니까 Node 프로젝트고, scripts에 release가 있으니까..." 하는 것의 토큰 차이는 크다.
