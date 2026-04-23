# release-docs

"릴리스해줘" 한 마디로 CHANGELOG + 버전 + 문서 + 릴리스를 자동화하는 Claude Code 플러그인.

## 특징

- **LLM 세션 컨텍스트 기반** — 커밋 메시지가 아닌, 대화 중 실제로 한 작업을 바탕으로 CHANGELOG 작성
- **프로젝트 자동 감지** — 설정 파일 없이 버전 파일, 릴리스 스크립트, CHANGELOG, 문서 디렉터리를 자동 탐지
- **스크립트 없는 프로젝트도 지원** — 릴리스 인프라가 없으면 직접 커밋+태그+푸시 수행
- **이중 커밋 방지** — 기존 릴리스 스크립트가 있으면 읽고 중복 동작 제거

## 설치

```
/plugin marketplace add <저장소-URL>
/plugin install release-docs
```

## 사용

세션 끝에 한 마디:

```
릴리스해줘
```

또는:

```
/release-docs
```

스킬이 자동으로:

1. 프로젝트 구조 감지 (package.json, pyproject.toml, Cargo.toml 등)
2. 세션에서 한 작업을 분류 (새 기능 / 버그 수정 / 개선 / 내부)
3. 버전 범프 결정 (breaking→major, feature→minor, fix→patch)
4. CHANGELOG 항목 작성 (사용자 관점, 기존 포맷 준수)
5. 기능 문서 업데이트 (필요 시)
6. 릴리스 실행 (빌드→커밋→태그→푸시)

## 지원 에코시스템

| 버전 파일 | 에코시스템 |
|----------|-----------|
| `package.json` | Node.js |
| `pyproject.toml` | Python |
| `Cargo.toml` | Rust |
| `build.gradle` | JVM |
| `VERSION` | 범용 |

## License

MIT
