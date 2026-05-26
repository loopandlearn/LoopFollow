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
EOF
