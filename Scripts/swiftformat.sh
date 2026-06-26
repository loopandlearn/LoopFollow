#! /bin/sh

# Only run inside a LoopFollow* directory (LoopFollow, LoopFollow_Second, LoopFollow_Third)
FOLDER_NAME=$(basename "${SRCROOT}")
case "${FOLDER_NAME}" in
    LoopFollow*) ;;
    *)
        echo "Skipping swiftformat: This script only runs in a LoopFollow* directory, not in '${FOLDER_NAME}'"
        exit 0
        ;;
esac

function assertEnvironment {
	if [ -z $1 ]; then 
		echo $2
		exit 127
	fi
}

assertEnvironment "${SRCROOT}" "Please set SRCROOT to project root folder"

unset SDKROOT

swift run -c release --package-path BuildTools swiftformat "${SRCROOT}" \
--header "LoopFollow\n{file}" \
--exclude Pods,Generated,R.generated.swift,fastlane/swift,Dependencies,dexcom-share-client-swift
