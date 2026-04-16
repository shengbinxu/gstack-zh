#!/usr/bin/env bash
# auto-sync-issue.sh
# Monitors open 'sync' issues in gstack-zh, runs Claude Code to fix them.
# Run via launchd or cron. Uses your local Claude Code subscription (no API key needed).
#
# Usage:
#   .scripts/auto-sync-issue.sh           # auto-detect open issue
#   .scripts/auto-sync-issue.sh 3         # process specific issue number

set -euo pipefail

REPO="shengbinxu/gstack-zh"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_FILE="$HOME/.local/logs/gstack-zh-sync.log"

mkdir -p "$(dirname "$LOG_FILE")"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

log "=== Starting sync check ==="
cd "$REPO_DIR"

# ── Pull latest main ──────────────────────────────────────────────────────────
git checkout main 2>/dev/null || true
git pull --ff-only origin main 2>/dev/null && log "main up to date" || log "WARN: pull failed, continuing"

# ── Find open sync issue ──────────────────────────────────────────────────────
if [ -n "${1:-}" ]; then
  ISSUE_NUMBER="$1"
  ISSUE_JSON=$(gh issue view "$ISSUE_NUMBER" --repo "$REPO" --json number,title,body,labels)
  # Verify it has sync label
  HAS_SYNC=$(echo "$ISSUE_JSON" | jq -r '[.labels[].name] | contains(["sync"])' 2>/dev/null || echo "false")
  if [ "$HAS_SYNC" != "true" ]; then
    log "Issue #$ISSUE_NUMBER does not have 'sync' label. Exiting."
    exit 1
  fi
else
  ISSUES=$(gh issue list --repo "$REPO" --label sync --state open --json number,title,body --limit 1)
  if [ "$(echo "$ISSUES" | jq 'length')" -eq 0 ]; then
    log "No open sync issues. Nothing to do."
    exit 0
  fi
  ISSUE_JSON=$(echo "$ISSUES" | jq '.[0]')
  ISSUE_NUMBER=$(echo "$ISSUE_JSON" | jq -r '.number')
fi

ISSUE_TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_JSON" | jq -r '.body')

log "Processing issue #$ISSUE_NUMBER: $ISSUE_TITLE"

# ── Check if PR already exists for this issue ─────────────────────────────────
EXISTING_PR=$(gh pr list --repo "$REPO" --head "auto-sync/issue-$ISSUE_NUMBER" --json number --jq '.[0].number' 2>/dev/null || echo "")
if [ -n "$EXISTING_PR" ]; then
  log "PR already exists (#$EXISTING_PR) for issue #$ISSUE_NUMBER. Skipping."
  exit 0
fi

# ── Update upstream clone ─────────────────────────────────────────────────────
log "Updating upstream gstack clone..."
if [ -d upstream/.git ]; then
  git -C upstream pull --ff-only 2>/dev/null || {
    log "upstream pull failed, re-cloning..."
    rm -rf upstream
    git clone --depth 1 https://github.com/garrytan/gstack.git upstream
  }
else
  git clone --depth 1 https://github.com/garrytan/gstack.git upstream
fi
log "upstream HEAD: $(git -C upstream log -1 --oneline)"

# ── Create feature branch ─────────────────────────────────────────────────────
BRANCH="auto-sync/issue-$ISSUE_NUMBER"
if git rev-parse --verify "$BRANCH" &>/dev/null; then
  git checkout "$BRANCH"
  git rebase main
else
  git checkout -b "$BRANCH"
fi
log "On branch: $BRANCH"

# ── Write issue content to temp file (avoids shell escaping issues) ───────────
ISSUE_FILE=$(mktemp /tmp/gstack-issue-XXXX.md)
trap 'rm -f "$ISSUE_FILE"' EXIT
cat > "$ISSUE_FILE" <<EOF
# Issue #$ISSUE_NUMBER: $ISSUE_TITLE

$ISSUE_BODY
EOF

# ── Run Claude Code ───────────────────────────────────────────────────────────
log "Running claude -p to update annotations..."

claude -p "
You are working on the gstack-zh repository — a Chinese annotation/study guide for garrytan/gstack.

## Repository (working directory: $REPO_DIR)

- \`docs/skills/*.md\` — one annotation file per gstack skill
- \`docs/*.md\` — other docs (architecture.md, how-skills-work.md, etc.)
- \`SYNC.md\` — tracks upstream sync state (synced-at + upstream-sha)
- \`upstream/\` — fresh clone of garrytan/gstack already in this directory

## Annotation format (docs/skills/<skill>.md)

Each section:
\`\`\`
### Section Title

> **原文**:
> [exact English original as blockquote]

**中文翻译**

[Chinese translation]

**设计原理解读**

[Why it's designed this way — not just what it does]
\`\`\`

Read CLAUDE.md for the full spec.

## Issue to process

$(cat "$ISSUE_FILE")

## Your task

1. **Parse the issue** — extract:
   - New upstream SHA (full 40-char, from the SYNC.md checklist section)
   - Changed files list (from the 'Changed files' code block)
   - Version string (from issue title, e.g. v0.17.0.0)

2. **Map changed files to annotation files**:
   - \`{skill}/SKILL.md\` or \`{skill}/SKILL.md.tmpl\` → update \`docs/skills/{skill}.md\`
   - \`ARCHITECTURE.md\` → update \`docs/architecture.md\`
   - \`CHANGELOG.md\`, \`VERSION\`, root \`SKILL.md\`, \`scripts/**\`, \`*/src/**\`, \`test/**\` → skip

3. **Update each annotation**:
   - Read upstream file from \`upstream/{skill}/SKILL.md\`
   - Read current annotation from \`docs/skills/{skill}.md\`
   - Add new sections (English original blockquote + Chinese + design analysis)
   - Update modified sections
   - If annotation doesn't exist yet, create it following existing files as template
   - Never delete existing Chinese analysis unless upstream deleted the section

4. **Update SYNC.md**:
   \`\`\`
   synced-at: $(date +%Y-%m-%d)
   upstream-sha: <full SHA from issue>
   \`\`\`

5. **Commit**:
   \`\`\`bash
   git add docs/ SYNC.md
   git commit -m 'sync: update annotations to gstack <version> (closes #$ISSUE_NUMBER)

   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>'
   \`\`\`
   Do NOT push — the script handles that.

Important: read CLAUDE.md first, never modify English originals in existing annotations.
" \
  --allowedTools "Read,Write,Edit,Bash,Glob,Grep" \
  --output-format text \
  2>&1 | tee -a "$LOG_FILE"

# ── Check if there's anything to push ────────────────────────────────────────
if git diff --quiet HEAD main 2>/dev/null; then
  log "No changes committed by Claude. Possibly nothing to update."
  git checkout main
  git branch -d "$BRANCH" 2>/dev/null || true
  exit 0
fi

# ── Push branch ───────────────────────────────────────────────────────────────
log "Pushing $BRANCH..."
git push origin "$BRANCH"

# ── Create PR ─────────────────────────────────────────────────────────────────
log "Creating PR..."
PR_URL=$(gh pr create \
  --repo "$REPO" \
  --title "sync: auto-update annotations ($ISSUE_TITLE)" \
  --body "$(cat <<EOF
## Summary

Auto-generated by local Claude Code sync script.

### What changed
- Updated annotation files in \`docs/skills/\` to reflect upstream changes
- Updated \`SYNC.md\` with new upstream SHA

Closes #$ISSUE_NUMBER
EOF
)" \
  --base main \
  --head "$BRANCH")

log "PR created: $PR_URL"

# ── Comment on issue ──────────────────────────────────────────────────────────
gh issue comment "$ISSUE_NUMBER" \
  --repo "$REPO" \
  --body "🤖 Local Claude Code has processed this sync. PR ready for review: $PR_URL"

log "=== Done. Issue #$ISSUE_NUMBER → $PR_URL ==="
