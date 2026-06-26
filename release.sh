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
# ---------------------------------------

# --- functions here ---
pause()     { read -rp "▶▶  Press Enter to continue (Ctrl-C to abort)…"; }
echo_run()  { echo "+ $*"; "$@"; }

push_cmds=()
queue_push() { push_cmds+=("git -C \"$(pwd)\" $*"); echo "+ [queued] (in $(pwd)) git $*"; }

update_follower () {
  local DIR="$1"
  local build_minute="$2"                     # staggered Sunday-build minute (see calls below)
  local suffix=".${DIR#${APP_NAME}_}"        # LoopFollow_Second  -> .Second
  local display="$DIR"                        # LoopFollow_Second
  local upstream="loopandlearn/${DIR}"        # loopandlearn/LoopFollow_Second

  echo; echo "🔄  Updating $DIR …"
  cd "$DIR"

  # 1 · Make sure we’re on a clean, up-to-date main
  echo_run git switch "$MAIN_BRANCH"
  echo_run git fetch
  echo_run git pull

  # 2 · Full mirror of the release tree from the primary repo.
  #     Every tracked file (including the overlay files) is synced; only git
  #     metadata and local/build dirs are protected. --delete makes the tree an
  #     exact mirror, auto-correcting any drift.
  echo_run rsync -a --delete \
    --exclude='.git/' \
    --exclude='.claude/' \
    --exclude='build/' \
    "$PRIMARY_ABS_PATH"/ ./

  # 3 · Re-apply this instance's overlay on top of the mirror
  perl -i -pe "s|^app_suffix\s*=.*|app_suffix = ${suffix}|"      LoopFollowDisplayNameConfig.xcconfig
  perl -i -pe "s|^display_name\s*=.*|display_name = ${display}|" LoopFollowDisplayNameConfig.xcconfig
  perl -i -pe "s|^(\s*)UPSTREAM_REPO:.*|\${1}UPSTREAM_REPO: ${upstream}|" .github/workflows/build_LoopFollow.yml
  perl -i -pe "s|^(\s*)- cron:.*|\${1}- cron: \"${build_minute} 10 * * 0\" # Sunday at UTC 10:${build_minute}|" .github/workflows/build_LoopFollow.yml

  # 4 · Rename the synced workspace to this instance's name
  rm -rf "${DIR}.xcworkspace"
  if [ -d "${APP_NAME}.xcworkspace" ]; then
    mv "${APP_NAME}.xcworkspace" "${DIR}.xcworkspace"
  fi

  # 5 · Single commit capturing the mirror + overlay
  git add -A
  if git diff --cached --quiet; then
    echo "✓  $DIR already up to date — nothing to commit."
  else
    echo_run git commit -m "transfer v${new_ver} updates from LF to ${DIR}"
  fi

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

# --- mirror the release tree into the sister repos ----
# Second arg = each app's scheduled browser-build minute (Sundays at 10:xx UTC),
# staggered from the main app (:17) so a user who forked all three apps doesn't
# trigger three simultaneous builds.
cd ..
update_follower "$SECOND_DIR" "27"
update_follower "$THIRD_DIR"  "40"

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
