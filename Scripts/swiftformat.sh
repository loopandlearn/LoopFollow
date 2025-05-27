#! /bin/sh

function assertEnvironment {
	if [ -z $1 ]; then 
		echo $2
		exit 127
	fi
}

assertEnvironment "${SRCROOT}" "Please set SRCROOT to project root folder"

unset SDKROOT

swift run -c release --package-path BuildTools swiftformat "${SRCROOT}" \
--header "LoopFollow\n{file}\nCreated by {author.name} on {created}." \
--exclude Pods,Generated,R.generated.swift,fastlane/swift,Dependencies,dexcom-share-client-swift
