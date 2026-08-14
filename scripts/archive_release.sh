#!/bin/bash
#
# Archive, verify and upload Cursor Sightline for the Mac App Store.
#
# Build 9 was rejected with ITMS-90301 because it was archived on a machine
# running a macOS seed. The toolchain was fine; the *host OS* is what gets
# stamped into BuildMachineOSBuild, and Apple rejects prerelease values at
# server-side processing. So this script refuses to produce an archive it
# knows Apple will bounce, and re-checks the value actually stamped into the
# binary before it will export or upload anything.
#
# Run it on a Mac booted from a released macOS. Usage:
#
#   scripts/archive_release.sh              # archive + verify + export
#   scripts/archive_release.sh --upload     # ... and upload to App Store Connect
#   scripts/archive_release.sh --smoke-test # rehearse everything short of Apple
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MouseGuide"
PROJECT="$REPO/MouseGuide.xcodeproj"
# Lives beside this script rather than in Distribution/, which is gitignored as
# a build-output directory -- it has to reach the release machine via git.
EXPORT_OPTIONS="$REPO/scripts/ExportOptions.plist"

BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$REPO/MouseGuide/Info.plist")"
ARCHIVE="${ARCHIVE_PATH:-/tmp/CursorSightline-$BUILD.xcarchive}"
EXPORT_DIR="${EXPORT_PATH:-/tmp/export-$BUILD}"

ASC_KEY_ID="${ASC_KEY_ID:-Y55Q877P98}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de73-6795-47e3-e053-5b8c7c11a4d1}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"

UPLOAD=0
SMOKE=0
case "${1:-}" in
	--upload) UPLOAD=1 ;;
	# Exercise every step that does not touch Apple: archive, metadata reads,
	# the export-options wiring. Downgrades the OS gates to warnings so the
	# script can be rehearsed on the seed machine before trusting it on the
	# release machine. Never exports or uploads -- distribution signing would
	# mint a certificate against the team's limited slots.
	--smoke-test) SMOKE=1 ;;
	"") ;;
	*) echo "usage: $(basename "$0") [--upload|--smoke-test]" >&2; exit 2 ;;
esac

# Apple seed builds look like 26A5388g: a four-digit number starting at 5000
# plus a trailing lowercase letter. Released builds (25F70, 26A320) do not.
is_prerelease_os() {
	[[ "$1" =~ ^[0-9]+[A-Z][5-9][0-9]{3}[a-z]$ ]]
}

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
warn() { printf '\n\033[1;33mWARN: %s\033[0m\n' "$*" >&2; }

# In smoke-test mode a gate reports instead of aborting.
gate() { if (( SMOKE )); then warn "$*"; else die "$*"; fi; }

# ---------------------------------------------------------------- host check
HOST_BUILD="$(sw_vers -buildVersion)"
say "Host: macOS $(sw_vers -productVersion) ($HOST_BUILD)"

# Checked up front, not at export time: these are the things a freshly-booted
# release volume is most likely to be missing.
[[ -f "$EXPORT_OPTIONS" ]] || die "Missing $EXPORT_OPTIONS"
[[ -f "$ASC_KEY_PATH" ]] || die "Missing App Store Connect key at $ASC_KEY_PATH
Copy AuthKey_$ASC_KEY_ID.p8 there, or set ASC_KEY_PATH."

if is_prerelease_os "$HOST_BUILD"; then
	gate "This Mac runs a prerelease macOS ($HOST_BUILD).

Every archive built here is stamped BuildMachineOSBuild=$HOST_BUILD, which
Apple rejects with ITMS-90301 during processing -- no matter which Xcode is
used. Run this script on a Mac booted from a released macOS instead.

Note that 'xcodebuild -exportArchive' and 'altool --validate-app' both pass
on such a build; the check is server-side, so local validation proves nothing."
fi

# --------------------------------------------------------------- toolchain
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
	XCODE_DEV="$DEVELOPER_DIR"
else
	# Prefer an explicitly-versioned, non-beta Xcode; fall back to xcode-select.
	XCODE_APP="$(ls -d /Applications/Xcode*.app 2>/dev/null | grep -iv beta | sort -V | tail -1)"
	XCODE_DEV="${XCODE_APP:+$XCODE_APP/Contents/Developer}"
	XCODE_DEV="${XCODE_DEV:-$(xcode-select -p)}"
fi

case "$XCODE_DEV" in
	*[Bb]eta*) die "Selected toolchain is a beta Xcode: $XCODE_DEV" ;;
esac

# Invoking Xcode's own xcodebuild directly sidesteps the license check that
# blocks /usr/bin/xcodebuild when xcode-select points at another install.
XCODEBUILD="$XCODE_DEV/usr/bin/xcodebuild"
[[ -x "$XCODEBUILD" ]] || die "No xcodebuild at $XCODEBUILD"
export DEVELOPER_DIR="$XCODE_DEV"

say "Toolchain: $("$XCODEBUILD" -version | tr '\n' ' ')"
say "Archiving Cursor Sightline build $BUILD"

rm -rf "$ARCHIVE"
"$XCODEBUILD" archive \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration Release \
	-destination 'generic/platform=macOS' \
	-archivePath "$ARCHIVE" \
	-allowProvisioningUpdates \
	-authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID" \
	| tail -20

# ------------------------------------------------------- verify the artifact
APP_PLIST="$(echo "$ARCHIVE"/Products/Applications/*.app/Contents/Info.plist)"
[[ -f "$APP_PLIST" ]] || die "No app bundle in $ARCHIVE"

get() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP_PLIST" 2>/dev/null || echo "<unset>"; }
STAMPED_OS="$(get BuildMachineOSBuild)"

say "Archive metadata"
printf '  BuildMachineOSBuild : %s\n' "$STAMPED_OS"
printf '  DTXcodeBuild        : %s\n' "$(get DTXcodeBuild)"
printf '  DTSDKBuild          : %s\n' "$(get DTSDKBuild)"
printf '  CFBundleVersion     : %s\n' "$(get CFBundleVersion)"

# The real gate: whatever the host claimed, this is the value Apple will read.
if is_prerelease_os "$STAMPED_OS"; then
	gate "Archive is stamped with a prerelease OS ($STAMPED_OS) -- ITMS-90301 again. Not exporting."
fi

# Guard against shipping a stale build number.
if [[ "$(get CFBundleVersion)" != "$BUILD" ]]; then
	die "Archive says build $(get CFBundleVersion) but Info.plist says $BUILD"
fi

if (( SMOKE )); then
	say "Smoke test complete -- archive built and verified."
	echo "  Stopping before export: distribution signing would mint a certificate"
	echo "  against the team's limited slots. Run without --smoke-test to export."
	exit 0
fi

say "Exporting to $EXPORT_DIR"
rm -rf "$EXPORT_DIR"
"$XCODEBUILD" -exportArchive \
	-archivePath "$ARCHIVE" \
	-exportPath "$EXPORT_DIR" \
	-exportOptionsPlist "$EXPORT_OPTIONS" \
	-authenticationKeyPath "$ASC_KEY_PATH" \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID" \
	| tail -20

PKG="$(ls "$EXPORT_DIR"/*.pkg 2>/dev/null | head -1)"
[[ -f "$PKG" ]] || die "No .pkg produced in $EXPORT_DIR"
say "Exported $PKG"

if (( UPLOAD )); then
	say "Uploading build $BUILD to App Store Connect"
	xcrun altool --upload-app -f "$PKG" -t macos \
		--apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
	say "Uploaded. Build $BUILD is now PROCESSING."
	cat <<-'EOF'
	  Processing is where ITMS-90301 was raised, so this is the only real
	  confirmation. Watch for the result, then:
	    - link the build to version 1.0 in App Store Connect
	    - complete the App Privacy questionnaire ("Data Not Collected")
	    - submit for review
	EOF
else
	say "Not uploaded. Re-run with --upload when you are ready."
fi
