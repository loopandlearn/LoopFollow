#!/usr/bin/env bash
# ------------------------------------------------------------
#  release.sh  – semi-automatic release helper
# ------------------------------------------------------------
set -euo pipefail
set -o errtrace
trap 'echo "❌  Error – aborting"; exit 1' ERR

# -------- configurable -----------------
APP_NAME="${1:-LoopFollow}"
SECOND_DIR="${APP_NAME}_Second"
THIRD_DIR="${APP_NAME}_Third"
VERSION_FILE="Config.xcconfig"
MARKETING_KEY="LOOP_FOLLOW_MARKETING_VERSION"
DEV_BRANCH="dev"
MAIN_BRANCH="main"
PATCH_DIR="../${APP_NAME}_update_patches"
# ---------------------------------------

# --- functions here ---
pause()     { read -rp "▶▶  Press Enter to continue (Ctrl-C to abort)…"; }
echo_run()  { echo "+ $*"; "$@"; }

push_cmds=()
queue_push() { push_cmds+=("git -C \"$(pwd)\" $*"); echo "+ [queued] (in $(pwd)) git $*"; }

update_follower () {
  local DIR="$1"
  echo; echo "🔄  Updating $DIR …"
  cd "$DIR"

  echo; echo "If there are custom changes needed to the patch, make the change before continuing"
  pause

  # 1 · Make sure we’re on a clean, up-to-date main
  echo_run git switch "$MAIN_BRANCH"
  echo_run git fetch
  echo_run git pull

  # 2 · Apply the patch
  if ! git apply --whitespace=nowarn "$PATCH_FILE"; then
    echo "‼️  Some changes could not be applied, so no changes were made."
    echo "The command used was: git apply --whitespace=nowarn $PATCH_FILE"
    echo; echo "Use a different terminal to fix and apply the patch before continuing"
    pause
  fi

  # 3 · Pause if any conflict markers remain
  if git ls-files -u | grep -q .; then
    echo "⚠️  Conflicts detected."
    echo "    If Fastfile or build_LoopFollow.yml were modified, these are expected."
    echo "    Open your merge tool, resolve, then press Enter."
    pause
  fi

  # 4 · Single commit capturing all staged changes
  git add -u
  git add $(git ls-files --others --exclude-standard) 2>/dev/null || true
  git commit -m "transfer v${new_ver} updates from LF to ${DIR}"

  echo_run git status
  echo "💻  Build & test $DIR now."; pause  # build & test checkpoint
  queue_push push origin "$MAIN_BRANCH"
  cd ..
}

# ---------- PRIMARY REPO ----------
PRIMARY_ABS_PATH="$(pwd -P)"
echo "🏁  Working in $PRIMARY_ABS_PATH …"

# --- start out in main to capture old_ver ---- 
echo_run git switch "$MAIN_BRANCH"
echo_run git fetch
echo_run git pull

# -------- version bump logic (unchanged) -----------
old_ver=$(grep -E "^${MARKETING_KEY}[[:space:]]*=" "$VERSION_FILE" | awk '{print $3}')
major_candidate="$(awk -F. '{printf "%d.0.0", $1 + 1}' <<<"$old_ver")"
minor_candidate="$(awk -F. '{printf "%d.%d.0", $1, $2 + 1}' <<<"$old_ver")"

echo
echo "Which version bump do you want?"
echo "  1) Major  →  $major_candidate"
echo "  2) Minor  →  $minor_candidate"
read -rp "Enter 1 or 2 (default = 2): " choice
echo

case "$choice" in
  1) new_ver="$major_candidate" ;; ""|2) new_ver="$minor_candidate" ;;
  *) echo "❌  Invalid choice – aborting."; exit 1 ;;
esac

echo "🔢  Bumping version: $old_ver  →  $new_ver"

# --- switch to dev so the release branch is cut from latest dev ----
echo_run git switch "$DEV_BRANCH"
echo_run git fetch
echo_run git pull

# --- create release branch from dev's tip ----
RELEASE_BRANCH="release/v${new_ver}"
echo_run git switch -c "$RELEASE_BRANCH"

# --- bump version on the release branch ----
sed -i '' "s/${MARKETING_KEY}[[:space:]]*=.*/${MARKETING_KEY} = ${new_ver}/" "$VERSION_FILE"
echo_run git diff "$VERSION_FILE"; pause
echo_run git commit -m "update version to ${new_ver} [skip ci]" "$VERSION_FILE"

echo "💻  Build & test release branch now."; pause
queue_push push origin "$RELEASE_BRANCH"

# --- create a patch from main..release branch (includes the bump) -----
mkdir -p "$PATCH_DIR"
PATCH_FILE="${PATCH_DIR}/LF_diff_${old_ver}_to_${new_ver}.patch"

git diff -M --binary "$MAIN_BRANCH" "$RELEASE_BRANCH"  \
  > "$PATCH_FILE"

cd ..
update_follower "$SECOND_DIR"
update_follower "$THIRD_DIR"

# ---------- GitHub Actions Test ---------
echo; 
echo "💻  Test GitHub Build Actions for all three repositories and then continue."; 
pause

# --- return to primary path
cd ${PRIMARY_ABS_PATH}

# ---------- push queue ----------
echo; echo "🚀  Ready to push changes upstream and open the release PR."
echo_run git log --oneline -2

read -rp "▶▶  Push everything now? (y/n): " confirm
if [[ $confirm =~ ^[Yy]$ ]]; then
  for cmd in "${push_cmds[@]}"; do echo "+ $cmd"; bash -c "$cmd"; done
  echo "🎉  All pushes completed."

  echo; echo "📝  Opening sync PR ${RELEASE_BRANCH} → ${DEV_BRANCH} …"
  gh pr create \
    --base "$DEV_BRANCH" \
    --head "$RELEASE_BRANCH" \
    --title "Sync v${new_ver} version bump to dev" \
    --body "Syncs the v${new_ver} version bump from the release branch back to \`dev\` so subsequent auto-bumps on \`dev\` continue from the released minor.

\`auto_version_dev\` detects that \`Config.xcconfig\` was changed in this push and skips re-bumping.

⚠️ **Use rebase-merge** (not squash or merge-commit) so \`dev\` and \`main\` end up at the same commit SHA after the release."

  echo; echo "📝  Opening release PR ${RELEASE_BRANCH} → ${MAIN_BRANCH} …"
  gh pr create \
    --base "$MAIN_BRANCH" \
    --head "$RELEASE_BRANCH" \
    --title "Release v${new_ver}" \
    --body "Release v${new_ver}.

Merging this PR triggers the tagging workflow, which creates tag \`v${new_ver}\` from \`LOOP_FOLLOW_MARKETING_VERSION\` in \`Config.xcconfig\`.

⚠️ **Use rebase-merge** (not squash or merge-commit) so \`dev\` and \`main\` end up at the same commit SHA after the release."

  echo; echo "🎉  All repos updated to v${new_ver} (local). Release PRs opened (sync → dev, release → main)."
  echo "👉  Review and merge both PRs — the tag will be created automatically by .github/workflows/tag_on_main.yml."
  echo "👉  Remember to create a GitHub release for tag v${new_ver} after the tag exists."
else
  echo "🚫  Pushes skipped.  Run manually if needed:"; printf '   %s\n' "${push_cmds[@]}"
  echo "🚫  Release not completed, pushes to GitHub were skipped"
fi
