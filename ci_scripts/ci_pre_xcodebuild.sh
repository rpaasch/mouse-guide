#!/bin/sh
#
# Xcode Cloud overwrites CFBundleVersion with its own run counter before
# archiving. That counter started at 1, so deliveries were landing as build 2
# while builds 8 and 9 were already on the 1.0 train -- App Store Connect wants
# the number to climb, not restart.
#
# Xcode Cloud runs this hook after its own rewrite and before xcodebuild, so
# this is where the number can be put back under our control. Info.plist stays
# authoritative for the base; the run counter only supplies uniqueness.
#
#   delivered build = CFBundleVersion (Info.plist) + CI_BUILD_NUMBER
#
# With the base at 10 that yields 13, 14, 15 ... -- always above 9, and always
# increasing as long as the base never drops.
#
set -e

PLIST="$CI_PRIMARY_REPOSITORY_PATH/MouseGuide/Info.plist"
BASE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")

if [ -z "$CI_BUILD_NUMBER" ]; then
	echo "CI_BUILD_NUMBER unset -- leaving CFBundleVersion at $BASE" >&2
	exit 0
fi

NEW=$((BASE + CI_BUILD_NUMBER))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW" "$PLIST"
echo "CFBundleVersion: $BASE + run $CI_BUILD_NUMBER -> $NEW"
