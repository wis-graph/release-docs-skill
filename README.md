# release-docs

"릴리스해줘" 한 마디로 CHANGELOG + 버전 + 문서 + 릴리스를 자동화하는 AI 코딩 도구 플러그인.

## 특징

- **LLM 세션 컨텍스트 기반** — 커밋 메시지가 아닌, 대화 중 실제로 한 작업을 바탕으로 CHANGELOG 작성
- **프로젝트 자동 감지** — 설정 파일 없이 버전 파일, 릴리스 스크립트, CHANGELOG, 문서 디렉터리를 자동 탐지
- **스크립트 없는 프로젝트도 지원** — 릴리스 인프라가 없으면 직접 커밋+태그+푸시 수행
- **이중 커밋 방지** — 기존 릴리스 스크립트가 있으면 읽고 중복 동작 제거
- **토큰 절약** — 기계적 작업은 스크립트가 처리, LLM은 CHANGELOG 텍스트 생성만

## 지원 플랫폼

| 플랫폼 | 인식 파일 | 설치 방법 |
|--------|----------|----------|
| Claude Code | `.claude-plugin/` | `/plugin install release-docs` |
| Codex (OpenAI) | `AGENTS.md` | 저장소 클론 후 참조 |
| Gemini CLI | `GEMINI.md` | 저장소 클론 후 참조 |

## 설치

### Claude Code

```bash
/plugin marketplace add https://github.com/wis-graph/release-docs-skill.git
/plugin install release-docs
```

설치 직후부터 동작:
- **UserPromptSubmit 훅** — "릴리스해줘" 키워드 감지 시 `detect.sh` 자동 실행
- **release-docs 스킬** — LLM이 세션 컨텍스트에서 CHANGELOG 생성 후 스크립트 호출

### Codex (OpenAI)

```bash
# 프로젝트 루트에 클론
git clone https://github.com/wis-graph/release-docs-skill.git .release-docs

# AGENTS.md를 프로젝트 루트에 복사 (또는 심볼릭 링크)
cp .release-docs/AGENTS.md ./AGENTS.md
```

Codex가 `AGENTS.md`를 자동으로 읽고 스크립트 경로(`.release-docs/scripts/`)를 참조합니다.

### Gemini CLI

```bash
# 프로젝트 루트에 클론
git clone https://github.com/wis-graph/release-docs-skill.git .release-docs

# GEMINI.md를 프로젝트 루트에 복사 (또는 심볼릭 링크)
cp .release-docs/GEMINI.md ./GEMINI.md
```

Gemini가 `GEMINI.md`를 자동으로 읽고 스크립트를 참조합니다.

### 기타 AI 코딩 도구 (Cursor, Windsurf 등)

```bash
git clone https://github.com/wis-graph/release-docs-skill.git .release-docs
```

해당 도구의 규칙 파일(`.cursorrules`, `.windsurfrules` 등)에 `skills/release-docs/SKILL.md` 내용을 붙여넣거나, 스크립트를 직접 호출하도록 안내합니다.

## 사용

```
릴리스해줘
```

자동으로:
1. `detect.sh` — 프로젝트 구조 감지 (훅이 자동 실행)
2. LLM — 세션 컨텍스트에서 변경 분류 + 버전 결정 + CHANGELOG 텍스트 생성
3. `changelog-insert.sh` — CHANGELOG에 항목 삽입
4. `release.sh` — 버전 범프 + 빌드 + 커밋 + 태그 + 푸시

## 스크립트

| 스크립트 | 역할 |
|---------|------|
| `scripts/detect.sh` | 프로젝트 구조 감지 → key=value 출력 |
| `scripts/bump-version.sh` | 버전 파일 수정 (모든 에코시스템) |
| `scripts/changelog-insert.sh` | CHANGELOG에 항목 삽입 |
| `scripts/release.sh` | 오케스트레이터 — 자체 스크립트 있으면 위임, 없으면 직접 수행 |

## 지원 에코시스템

| 버전 파일 | 에코시스템 |
|----------|-----------|
| `package.json` | Node.js |
| `pyproject.toml` | Python |
| `Cargo.toml` | Rust |
| `build.gradle` | JVM |
| `VERSION` | 범용 |

## 구조

```
release-docs-plugin/
├── .claude-plugin/        ← Claude Code 플러그인 매니페스트
├── skills/release-docs/
│   └── SKILL.md           ← LLM 워크플로우 (CHANGELOG 생성 중심)
├── scripts/
│   ├── detect.sh          ← 프로젝트 감지
│   ├── bump-version.sh    ← 버전 범프
│   ├── changelog-insert.sh ← CHANGELOG 삽입
│   └── release.sh         ← 릴리스 오케스트레이터
├── hooks/
│   └── hooks.json         ← 키워드 감지 훅
├── AGENTS.md              ← Codex/OpenAI 지원
├── GEMINI.md              ← Gemini CLI 지원
└── README.md
```

## License

MIT
