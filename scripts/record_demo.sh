#!/bin/bash
#
# Records the screen demo App Review asked for under Guideline 2.1: launching
# the app, the menu bar icon, the crosshair following the pointer, Settings,
# and where the in-app purchase is offered.
#
# Records the WHOLE screen on purpose -- Apple wants to see the app launch and
# the menu bar, which a window-only capture cannot show. A backdrop window
# covers everything else; hiding the other apps was tried first and let a whole
# chat window, project names and all, into the frame. WATCH THE RECORDING
# BEFORE SENDING IT anyway -- whatever is on screen goes to Apple.
#
# Two things this deliberately does NOT do:
#
#   * It never clicks Buy Now. A script must not be able to start a purchase.
#     To get the payment sheet on camera, click it yourself while recording.
#   * It does not reset the permission prompts. Those are granted already, so
#     they will not reappear. If you want them in the recording, revoke them
#     first in System Settings > Privacy & Security (Input Monitoring and
#     Screen Recording), then run this.
#
# Usage: scripts/record_demo.sh [en|da] [output.mov]
#
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOCALE="${1:-en}"
OUT="${2:-$HERE/shots/cursor-sightline-demo-$LOCALE.mov}"
DURATION=78   # the sequence runs ~62s; the rest is headroom so nothing is cut off

APP="${DEMO_APP:-/Users/rp/Library/Developer/Xcode/DerivedData/MouseGuide-bwfkadnrzkysetaxyhrbffjaqryn/Build/Products/Debug/Cursor Sightline.app}"
[ -d "$APP" ] || APP="/Applications/Cursor Sightline.app"
PREFS="$HOME/Library/Containers/dk.netdot.sightline.app/Data/Library/Preferences/dk.netdot.sightline.app"

if [ ! -d "$APP" ]; then
	echo "No app bundle found. Build it, or set DEMO_APP=/path/to/Cursor Sightline.app" >&2
	exit 1
fi

if [ "$LOCALE" = "da" ]; then
	SHOW="Vis Cursor Sightline"; SETTINGS="Indstillinger..."; TITLE="Indstillinger"
else
	SHOW="Show Cursor Sightline"; SETTINGS="Settings..."; TITLE="Settings"
fi

mkdir -p "$(dirname "$OUT")"
for tool in setmode warpmouse backdrop; do
	[ -x "$HERE/$tool" ] || swiftc -O "$HERE/$tool.swift" -o "$HERE/$tool" || exit 1
done

BACKDROP=""
restore() {
	[ -n "$BACKDROP" ] && kill "$BACKDROP" 2>/dev/null
	pkill -x "Cursor Sightline" 2>/dev/null
	"$HERE/setmode" 2704 1756 >/dev/null 2>&1
	osascript -e 'tell application "System Events" to set visible of process "Terminal" to true' 2>/dev/null
}
trap restore EXIT

# --- menu helpers -----------------------------------------------------------
# The app is an accessory (LSUIElement) with no Dock icon, so its menu is only
# reachable through the status bar (menu bar 2).
# The menu is left open for a beat before the item is chosen. At the AppleScript
# default it opened and closed inside a single second -- present in the
# recording, but far too quick for a reviewer to notice, and this menu is the
# app's entire interface.
open_menu_item() {
	osascript <<-EOF 2>/dev/null
	tell application "System Events"
		tell process "Cursor Sightline"
			click menu bar item 1 of menu bar 2
			delay 2.5
			click menu item "$1" of menu 1 of menu bar item 1 of menu bar 2
		end tell
	end tell
	EOF
}

# --- stage ------------------------------------------------------------------
pkill -x "Cursor Sightline" 2>/dev/null
"$HERE/setmode" 2560 1600 || exit 1
sleep 2

defaults write "$PREFS" hasCompletedFirstRun -bool true
defaults write "$PREFS" language -string "$LOCALE"

# Cover the screen. Hiding the other apps was tried and is not reliable -- an
# Electron app ignored it and its whole window, project names and all, ended up
# in the first recording. A backdrop window cannot fail that way.
"$HERE/backdrop" 1d2433 &
BACKDROP=$!
sleep 2
"$HERE/warpmouse" 640 400

echo "Recording ${DURATION}s to $OUT"
screencapture -v -V "$DURATION" -k -C -x "$OUT" &
REC=$!
sleep 4   # let the recording settle on a clean desktop before anything happens

# 1. Launch. The menu bar icon appearing is the first thing Apple should see.
#    Deliberately WITHOUT -fullAccessForScreenshots: that flag calls
#    showCrosshairs() itself at launch, so the menu click below would toggle the
#    crosshair straight back off -- which is exactly what ruined the first take.
#    Without it the app behaves as it does for a real user, which is what a
#    reviewer should be watching anyway.
open -a "$APP"
sleep 6

# 2. Turn the crosshair on from the menu.
open_menu_item "$SHOW"
sleep 3

# 3. The core feature: the crosshair tracking the pointer. Slow, deliberate
#    moves -- a reviewer has to be able to follow what is happening.
# Points, not pixels. The display is 1280x800 points (2560x1600 pixels), and
# anything beyond that gets clamped to the edge -- which silently reduced the
# crosshair to a single line hard against the border on the previous take.
for point in "320 220" "960 260" "1080 620" "420 640" "760 380" "640 400"; do
	"$HERE/warpmouse" $point
	sleep 2.5
done

# 4. Settings, landing on the Appearance pane with the display modes.
open_menu_item "$SETTINGS"
sleep 3
osascript <<-EOF 2>/dev/null
tell application "System Events"
	tell process "Cursor Sightline"
		set frontmost to true
		set w to first window whose title is "$TITLE"
		set position of w to {215, 45}
		set size of w to {850, 700}
		perform action "AXRaise" of w
	end tell
end tell
EOF
sleep 3
"$HERE/warpmouse" 700 400
sleep 4

# 5. The purchase location. Sidebar rows sit 32 points apart from Appearance at
#    y=123, so License -- the third -- is at 187. Stop here: showing where the
#    purchase lives is the point, and clicking Buy Now is not this script's job.
"$HERE/warpmouse" 300 187 click
sleep 3
"$HERE/warpmouse" 700 500
sleep 6

wait $REC
echo "Done: $OUT"
echo "Watch it before sending -- the desktop background is in frame."
