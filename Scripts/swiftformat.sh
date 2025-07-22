#! /bin/sh

# Check if the folder name is exactly "LoopFollow"
FOLDER_NAME=$(basename "${SRCROOT}")
if [ "${FOLDER_NAME}" != "LoopFollow" ]; then
    echo "Skipping swiftformat: This script only runs in the LoopFollow directory, not in '${FOLDER_NAME}'"
    exit 0
fi

function assertEnvironment {
	if [ -z $1 ]; then 
		echo $2
		exit 127
	fi
}

assertEnvironment "${SRCROOT}" "Please set SRCROOT to project root folder"

unset SDKROOT

swift run -c release --package-path BuildTools swiftformat "${SRCROOT}" \
--header "LoopFollow\n{file}\nCreated by {author.name}." \
--exclude Pods,Generated,R.generated.swift,fastlane/swift,Dependencies,dexcom-share-client-swift
