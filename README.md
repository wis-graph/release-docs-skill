# release-docs

"**릴리스**" / "**변경사항**" / "**변경기록**" 한 마디로 CHANGELOG + 버전 + 문서 + (선택) 릴리스를 자동화하는 AI 코딩 도구 플러그인.

## 특징

- **두 가지 사용 모드, 하나의 플로우** — 실제로 배포까지 하는 사람은 "릴리스", 배포 없이 로컬 CHANGELOG + 버전 태그만 쓰는 사람은 "변경사항" / "변경기록". 내부 동작은 동일
- **LLM 세션 컨텍스트 기반** — 커밋 메시지가 아닌, 대화 중 실제로 한 작업을 바탕으로 CHANGELOG 작성
- **프로젝트 자동 감지** — 설정 파일 없이 버전 파일, 릴리스 스크립트, CHANGELOG, 문서 디렉터리를 자동 탐지
- **원격 없으면 push 자동 스킵** — 로컬 커밋·태그만. GitHub 빈 릴리스 사고 방지
- **빈 릴리스 방지 게이트** — 릴리스 인프라가 전혀 없는 프로젝트는 자동 진행 대신 사용자 확인을 요구
- **이중 커밋 방지** — 기존 릴리스 스크립트가 있으면 읽고 중복 동작 제거
- **토큰 절약** — 기계적 작업은 스크립트가 처리, LLM은 CHANGELOG 텍스트 생성만

## 설치 (프로젝트 로컬 — 권장)

**로컬 설치를 기본으로 합니다.** 훅이 해당 프로젝트에서만 작동하고, 다른 프로젝트는 영향받지 않으며, 팀원과 `.claude/settings.json`을 공유할 수 있습니다.

### 공통 단계 — 프로젝트에 클론

```bash
cd /path/to/your/project
git clone https://github.com/wis-graph/release-docs-skill.git .release-docs
echo ".release-docs/" >> .gitignore  # 또는 서브모듈로 관리
```

### Claude Code

프로젝트 루트에 `.claude/settings.json`을 생성/수정:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "릴리스|변경사항|변경기록|release|Release|changelog|Changelog",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$CLAUDE_PROJECT_DIR/.release-docs/scripts/detect.sh\" \"$CLAUDE_PROJECT_DIR\"",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

스킬도 프로젝트 로컬로 인식되게 하려면:

```bash
mkdir -p .claude/skills
ln -s ../../.release-docs/skills/release-docs .claude/skills/release-docs
```

설치 직후부터 동작:
- **UserPromptSubmit 훅** — 트리거 키워드(`릴리스` / `변경사항` / `변경기록` / `release` / `changelog`) 감지 시 `detect.sh` 자동 실행
- **release-docs 스킬** — LLM이 세션 컨텍스트에서 CHANGELOG 생성 후 스크립트 호출

### Codex (OpenAI)

```bash
cp .release-docs/AGENTS.md ./AGENTS.md
```

Codex가 `AGENTS.md`를 자동으로 읽고 스크립트 경로(`.release-docs/scripts/`)를 참조합니다.

### Gemini CLI

```bash
cp .release-docs/GEMINI.md ./GEMINI.md
```

Gemini가 `GEMINI.md`를 자동으로 읽고 스크립트를 참조합니다.

### 기타 AI 코딩 도구 (Cursor, Windsurf 등)

해당 도구의 규칙 파일(`.cursorrules`, `.windsurfrules` 등)에 `.release-docs/skills/release-docs/SKILL.md` 내용을 붙여넣거나, 스크립트를 직접 호출하도록 안내합니다.

## 설치 (글로벌 — 대안)

모든 프로젝트에서 쓰고 싶다면 Claude Code 마켓플레이스로 글로벌 설치도 가능합니다. 훅이 전역적으로 활성화되므로 주의하세요.

```bash
/plugin marketplace add https://github.com/wis-graph/release-docs-skill.git
/plugin install release-docs
```

## 동작 원리

자세한 아키텍처와 흐름은 **[docs/how-it-works.md](docs/how-it-works.md)** 참조.

## 사용

배포까지 할 것이면:
```
릴리스해줘
```

배포 없이 로컬에 변경 기록만 남길 것이면:
```
변경사항 기록해줘
```
또는
```
변경기록
```

어느 쪽이든 자동으로:
1. `detect.sh` — 프로젝트 구조 감지 (훅이 자동 실행)
2. LLM — 세션 컨텍스트에서 변경 분류 + 버전 결정 + CHANGELOG 텍스트 생성
3. `changelog-insert.sh` — CHANGELOG에 항목 삽입 (없으면 생성)
4. `release.sh` — 버전 범프 + 빌드 + 커밋 + 태그 + (원격 있을 때만) 푸시
   - **원격 저장소가 없으면 push는 자동 스킵** — 로컬 커밋·태그만 남음 → GitHub 빈 릴리스 사고 없음
   - 버전 파일 없으면 `VERSION` 자동 생성

## 릴리스 준비도 게이트

**릴리스 인프라가 전혀 없는 프로젝트에서 자동 릴리스하면 GitHub에 빈 태그/릴리스가 올라가는 사고가 생깁니다.** 이를 막기 위해 준비도 게이트가 있습니다.

| 프로젝트 상태 | `RELEASE_READY` | 동작 |
|--------------|-----------------|------|
| 버전 파일 OR 릴리스 스크립트 OR 이전 태그 중 하나라도 있음 | `true` | 자동으로 CHANGELOG 생성 + 범프 + 커밋 + 태그 + 푸시 |
| 셋 다 없음 | `false` | `release.sh`가 `exit 2`로 **중단**. LLM이 사용자에게 "첫 릴리스로 진행할지 / 취소할지" 확인 |

사용자가 첫 릴리스를 승인하면 `release.sh <bump> . --first-release`로 호출되어:

- **버전 파일 없음** → `VERSION` 파일을 `0.1.0`(또는 `LATEST_TAG` 값)으로 생성
- **CHANGELOG 없음** → `CHANGELOG.md` 자동 생성
- **원격 없음** → 푸시 건너뛰고 로컬 커밋/태그만 생성 (원격에 빈 릴리스 안 올라감)

한 번 첫 릴리스를 끝내면 그 뒤로는 `RELEASE_READY=true`가 되어 평소처럼 `릴리스해줘` 한 마디로 자동 동작합니다.

## 스크립트

| 스크립트 | 역할 |
|---------|------|
| `scripts/detect.sh` | 프로젝트 구조 감지 → key=value 출력 |
| `scripts/bump-version.sh` | 버전 파일 수정 (모든 에코시스템) |
| `scripts/changelog-insert.sh` | CHANGELOG에 항목 삽입 (없으면 생성) |
| `scripts/release.sh` | 오케스트레이터 — 자체 스크립트 있으면 위임, 없으면 직접 수행 |

## 지원 에코시스템

| 버전 파일 | 에코시스템 |
|----------|-----------|
| `package.json` | Node.js |
| `pyproject.toml` | Python |
| `Cargo.toml` | Rust |
| `build.gradle` | JVM |
| `VERSION` | 범용 (자동 생성 대상) |

## 구조

```
release-docs-plugin/
├── .claude-plugin/        ← Claude Code 글로벌 설치용 매니페스트
├── skills/release-docs/
│   └── SKILL.md           ← LLM 워크플로우 (CHANGELOG 생성 중심)
├── scripts/
│   ├── detect.sh          ← 프로젝트 감지
│   ├── bump-version.sh    ← 버전 범프
│   ├── changelog-insert.sh ← CHANGELOG 삽입/생성
│   └── release.sh         ← 릴리스 오케스트레이터
├── hooks/
│   └── hooks.json         ← 글로벌 설치 시 키워드 감지 훅
├── AGENTS.md              ← Codex/OpenAI 지원
├── GEMINI.md              ← Gemini CLI 지원
└── README.md
```

## License

MIT
