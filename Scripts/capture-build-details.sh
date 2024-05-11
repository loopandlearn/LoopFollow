#!/bin/sh -e

#  capture-build-details.sh
#  LoopFollow
#
#  Created by Jonas Björkert on 2024-05-08.

# Enable debugging if needed
#set -x

# Define the base path for the BuildDetails.plist
info_plist_base="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}"

# Adjust the path for macOS Catalyst builds to include the Resources directory
if [[ "$PLATFORM_NAME" == *"macosx"* ]]; then
  info_plist_base+="/Resources"
fi

info_plist_path="${info_plist_base}/BuildDetails.plist"

# Ensure the path to BuildDetails.plist is valid.
if [ "${info_plist_path}" == "/" -o ! -e "${info_plist_path}" ]; then
    echo "$PLATFORM_NAME"
    echo "BuildDetails.plist file does not exist at path: ${info_plist_path}" >&2
    exit 1
else
    echo "Gathering build details..."

    # Capture the current date and write it to BuildDetails.plist
    formatted_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    plutil -replace com-LoopFollow-build-date -string "$formatted_date" "${info_plist_path}"

    # Retrieve the current branch
    git_branch=$(git symbolic-ref --short -q HEAD)

    # Attempt to retrieve the current tag
    git_tag=$(git describe --tags --exact-match 2>/dev/null || echo "")

    # Retrieve the current SHA of the latest commit
    git_commit_sha=$(git log -1 --format="%h" --abbrev=7)

    # Determine the branch or tag information
    git_branch_or_tag="${git_branch:-${git_tag}}"

    # Update BuildDetails.plist with the branch or tag information
    plutil -replace com-LoopFollow-branch -string "${git_branch_or_tag}" "${info_plist_path}"

    # Update BuildDetails.plist with the SHA information
    plutil -replace com-LoopFollow-commit-sha -string "${git_commit_sha}" "${info_plist_path}"
fi
