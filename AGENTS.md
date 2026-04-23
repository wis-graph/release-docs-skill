# Release Docs — Agent Instructions

When the user says "릴리스해줘", "release", or asks to ship/version-bump:

## Step 1: Detect project structure
Run: `bash scripts/detect.sh .`
This outputs key=value pairs: VERSION_FILE, CURRENT_VERSION, ECOSYSTEM, RELEASE_SCRIPT, CHANGELOG, DOCS_DIR

## Step 2: If RELEASE_SCRIPT is set, read it
Determine which steps (build/commit/tag/push/version-bump) the script handles to avoid duplication.

## Step 3: Classify changes from session context
Categories: Breaking, New Feature, Bug Fix, Improvement, Internal

## Step 4: Decide version bump (do NOT ask the user)
- Breaking → major (minor if < 1.0)
- New feature → minor (patch if < 1.0)
- Bug fix/improvement only → patch

Report the decision, don't ask for confirmation.

## Step 5: Generate CHANGELOG text
- User perspective only — no function names, file names, or internal details
- Based on session context, NOT commit messages
- Match existing CHANGELOG format if one exists

## Step 6: Insert CHANGELOG
Run: `echo "<generated text>" | bash scripts/changelog-insert.sh <CHANGELOG_PATH>`

## Step 7: Release
Run: `bash scripts/release.sh <bump_type> .`
This auto-delegates to the project's own release script if one exists.

## Rules
- Never ask "which version?" — decide automatically
- Never ask "proceed?" — report and execute
- Never expose function names in CHANGELOG
- Always read RELEASE_SCRIPT before executing to prevent double-commit
