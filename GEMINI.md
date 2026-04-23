# Release Docs — Gemini Instructions

## Skill: release-docs
**Trigger:** "릴리스해줘", "release", version-bump request

This plugin provides scripts for automated releases. Your job is to generate CHANGELOG text from session context — scripts handle everything else.

### Available Scripts
| Script | Purpose | Usage |
|--------|---------|-------|
| `.release-docs/scripts/detect.sh .` | Detect project structure | Outputs key=value (VERSION_FILE, RELEASE_SCRIPT, etc.) |
| `.release-docs/scripts/changelog-insert.sh <path>` | Insert CHANGELOG entry | Pipe text via stdin |
| `.release-docs/scripts/bump-version.sh <file> <ver>` | Bump version file | Direct call |
| `.release-docs/scripts/release.sh <type> .` | Full release orchestration | Auto-delegates to project script if exists |

### Workflow
1. Run `.release-docs/scripts/detect.sh` → read output
2. If RELEASE_SCRIPT found → read it (prevent duplicate steps)
3. Classify session changes (Breaking/Feature/Fix/Improvement/Internal)
4. Decide version bump automatically (don't ask user)
5. Generate CHANGELOG text (user perspective, match existing format)
6. Run `.release-docs/scripts/changelog-insert.sh` with generated text
7. Run `.release-docs/scripts/release.sh` with bump type

### Rules
- Never ask user for version bump decision
- Never ask for confirmation before executing
- CHANGELOG must be user-perspective only (no code internals)
- Based on session context, not commit messages
