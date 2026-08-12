#!/bin/bash
# Captures the License pane, which App Store Connect requires as the review
# screenshot for the in-app purchase - a reviewer has to see where the purchase
# is offered. Separate from shoot.sh because this one is not a store listing
# image: it never gets shown to customers and has no fixed size requirement.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/shots"
APP="/Users/rp/Library/Developer/Xcode/DerivedData/MouseGuide-bwfkadnrzkysetaxyhrbffjaqryn/Build/Products/Debug/Cursor Sightline.app"
PREFS="$HOME/Library/Containers/dk.netdot.sightline.app/Data/Library/Preferences/dk.netdot.sightline.app"

LOCALE="${1:-en}"
TITLE="Settings"; ROW="License"
[ "$LOCALE" = "da" ] && { TITLE="Indstillinger"; ROW="Licens"; }

mkdir -p "$OUT"
for tool in setmode pngtool warpmouse; do
    [ -x "$HERE/$tool" ] || swiftc -O "$HERE/$tool.swift" -o "$HERE/$tool" || exit 1
done

restore() {
    pkill -x "Cursor Sightline" 2>/dev/null
    "$HERE/setmode" 2704 1756 >/dev/null 2>&1
    osascript -e 'tell application "System Events" to set visible of process "Terminal" to true' 2>/dev/null
}
trap restore EXIT

pkill -x "Cursor Sightline" 2>/dev/null
# Quit rather than hide: hiding every other app makes macOS activate whatever
# is next in line, and that app then covers the settings window.
osascript -e 'tell application "TextEdit" to quit' 2>/dev/null
sleep 1
"$HERE/setmode" 2560 1600 || exit 1
sleep 2

defaults write "$PREFS" hasCompletedFirstRun -bool true
defaults write "$PREFS" language -string "$LOCALE"
open -a "$APP" --args -fullAccessForScreenshots -showSettingsForScreenshots
sleep 4

osascript <<EOF 2>/dev/null
tell application "System Events"
    tell process "Cursor Sightline"
        set w to first window whose title is "$TITLE"
        set position of w to {215, 45}
        set size of w to {850, 700}
    end tell
end tell
EOF
sleep 1

# The sidebar rows sit 32 points apart from Appearance at y=123; License is the
# third. Selecting it by clicking is the only route - the pane is @State inside
# SwiftUI and no launch argument reaches it.
"$HERE/warpmouse" 300 187 click
sleep 2

osascript <<'EOF'
tell application "System Events"
    set targets to name of every process whose visible is true
end tell
repeat with n in targets
    if (n as text) is not "Cursor Sightline" then
        try
            tell application "System Events" to set visible of process (n as text) to false
        end try
    end if
end repeat
EOF
sleep 2

# The app is an accessory (LSUIElement), so it does not win activation by
# default - raise its window explicitly after everything else has gone.
osascript <<EOF 2>/dev/null
tell application "System Events"
    tell process "Cursor Sightline"
        set frontmost to true
        perform action "AXRaise" of (first window whose title is "$TITLE")
    end tell
end tell
EOF
sleep 1

# Park the pointer outside the crop so the overlay does not run through the shot.
"$HERE/warpmouse" 1200 760
sleep 0.3
screencapture -x -t png "$OUT/iap-review-$LOCALE.png"

# Crop to the settings window. Hiding the other apps is unreliable here - the
# accessory app does not hold activation, so something usually creeps back into
# frame - and this shot must not carry the desktop or anyone's file names into
# an App Store review. Window is {215,45} 850x700 points, so double for pixels.
sips -c 1400 1700 --cropOffset 90 430 "$OUT/iap-review-$LOCALE.png" \
     --out "$OUT/iap-review-$LOCALE.png" >/dev/null
"$HERE/pngtool" flatten "$OUT/iap-review-$LOCALE.png" "$OUT/iap-review-$LOCALE.png"

osascript -e 'tell application "System Events" to set visible of process "Terminal" to true' 2>/dev/null
echo "captured iap-review-$LOCALE"
