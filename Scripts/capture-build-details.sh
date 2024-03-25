#!/bin/sh -e

#  capture-build-details.sh
#  LoopFollow
#
#  Created by Jonas Björkert on 2024-03-25.
#  Copyright © 2024 Jon Fawcett. All rights reserved.

info_plist_path="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/BuildDetails.plist"

# Ensure the path to BuildDetails.plist is valid.
if [ "${info_plist_path}" == "/" -o ! -e "${info_plist_path}" ]; then
  echo "ERROR: BuildDetails.plist file does not exist at path: ${info_plist_path}" >&2
  exit 1
fi

echo "Gathering build date..."

# Capture the current date and write it to BuildDetails.plist
plutil -replace com-loopkit-Loop-build-date -string "$(date)" "${info_plist_path}"
