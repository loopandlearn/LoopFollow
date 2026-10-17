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
4. Run the SwiftFormat lint check (see `## SwiftFormat` below) against every file touched by
   the cherry-picked commit(s). Fix any violations found — touching only those files/lines,
   nothing else in the repo — then amend the cherry-picked commit (or add a fixup commit) so
   the branch is lint-clean before it's pushed. Do not open the PR with unresolved violations.
5. `git push origin pr/<feature-name>` — push and open the PR from this branch

## Upstream PR standards (loopandlearn/LoopFollow)
- **One concern per PR** — one bug fix, one feature, or one improvement. Split unrelated changes into separate PRs.
- **Branch naming** — use a descriptive name reflecting the purpose (e.g. `fix/mmol-color-display`).
- **Do not update version numbers** — only project maintainers do that.

## Commit message format
Messages should complete the sentence: *"If applied, this commit will..."*

- Use imperative mood: "Fix crash" not "Fixed crash"
- Capitalise the first letter, no trailing period
- Subject line: 50 characters max
- Body (if needed): wrap at 72 characters

Good examples:
- `Fix mmol/L color comparison using display-unit precision`
- `Add alarm snooze functionality`
- `Update documentation for build process`

## No AI co-referencing
Never mention Claude, AI, or any AI tooling in:
- Code
- Code comments
- Commit messages
- PR titles or descriptions

All output should read as if written by a human developer.

## SwiftFormat
This project enforces formatting via SwiftFormat 0.56.1 (pinned in `BuildTools/Package.swift`),
run in CI exactly as:

    swift run -c release --package-path BuildTools swiftformat . \
      --lint \
      --header "LoopFollow\n{file}" \
      --exclude Pods,Generated,R.generated.swift,fastlane/swift,Dependencies,dexcom-share-client-swift

There is no `.swiftlint.yml` and no SwiftLint step anywhere in this repo — only SwiftFormat is
enforced. There is also no `.swiftformat` config file; rules are SwiftFormat's *defaults* plus
the header template above.

Before finishing any task that touches `.swift` files:
- Run the command above (drop `--lint` to auto-fix) against the repo, or at minimum against
  every file you touched, and resolve every reported violation.
- If the Swift toolchain isn't available in this session, don't guess — check for
  `scripts/lint.sh` or ask the user to run the check, and manually verify against known
  defaults: exact 2-line file header (`// LoopFollow` / `// {file}`) followed by a blank line,
  space around all operators/commas, no trailing blank line before a closing brace, blank line
  before and after `// MARK:` comments, no consecutive spaces, and consistent indentation of
  wrapped literals.
- Only fix violations in files/lines you touched — don't reformat unrelated files in the same PR.
- Never mark a task done, or hand back a "ready" branch, with unresolved SwiftFormat violations.
EOF
