#!/bin/bash
set -euo pipefail

# Only run in remote (web) sessions
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Write CLAUDE.md with project instructions.
# CLAUDE.md is listed in .gitignore so it never pollutes upstream PRs,
# but this hook recreates it on every fresh remote session.
cat > "$CLAUDE_PROJECT_DIR/CLAUDE.md" << 'EOF'
# LoopFollow – Claude Instructions

## Branching
- **Always branch off `dev`**, never off `main`.
- All pull requests should target `dev`.

## Sending a PR upstream
When the user says "ready", execute these steps to create a clean upstream PR branch that excludes fork-only files (e.g. `.claude/`):

1. `git fetch origin dev` — get the latest upstream dev
2. `git checkout -b pr/<feature-name> origin/dev` — create a clean branch rooted at upstream's dev
3. `git cherry-pick <commit-sha>` — apply only the relevant fix commit(s)
4. `git push origin pr/<feature-name>` — push and open the PR from this branch
EOF
