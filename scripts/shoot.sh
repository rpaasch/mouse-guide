#!/bin/bash
# App Store screenshot capture for Cursor Sightline, Danish and English.
#
# Captures at 2560x1600 - one of the four sizes App Store Connect accepts for
# macOS - by switching the display to its 1280x800 HiDPI mode, so nothing has
# to be rescaled afterwards. Display, wallpaper and TextEdit prefs are all
# restored on any exit path.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/shots"
APP="/Users/rp/Library/Developer/Xcode/DerivedData/MouseGuide-bwfkadnrzkysetaxyhrbffjaqryn/Build/Products/Debug/Cursor Sightline.app"
PREFS="$HOME/Library/Containers/dk.netdot.sightline.app/Data/Library/Preferences/dk.netdot.sightline.app"

NATIVE_W=2704
NATIVE_H=1756
SHOT_W=2560
SHOT_H=1600

BG=/tmp/sightline_shoot_bg.png
OLD_BG="$(osascript -e 'tell application "System Events" to get picture of current desktop' 2>/dev/null)"

OLD_LOCALE="$(defaults read -g AppleLocale 2>/dev/null)"
OLD_SHOWDATE="$(defaults read com.apple.menuextra.clock ShowDate 2>/dev/null)"
OLD_SHOWDOW="$(defaults read com.apple.menuextra.clock ShowDayOfWeek 2>/dev/null)"

mkdir -p "$OUT"
rm -f "$OUT"/*.png

# The three helper binaries are build products, not sources - compile any that
# are missing so a fresh checkout can run this without setup.
for tool in setmode pngtool warpmouse; do
    if [ ! -x "$HERE/$tool" ]; then
        echo "building $tool"
        swiftc -O "$HERE/$tool.swift" -o "$HERE/$tool" || exit 1
    fi
done

restore() {
    pkill -x "Cursor Sightline" 2>/dev/null
    "$HERE/setmode" "$NATIVE_W" "$NATIVE_H" >/dev/null 2>&1
    [ -n "$OLD_BG" ] && osascript -e "tell application \"System Events\" to set picture of every desktop to \"$OLD_BG\"" 2>/dev/null
    osascript -e 'tell application "System Events" to set visible of process "Terminal" to true' 2>/dev/null
    defaults delete com.apple.TextEdit NSFixedPitchFontSize 2>/dev/null
    defaults delete com.apple.TextEdit AppleLanguages 2>/dev/null
    [ -n "$OLD_LOCALE" ] && defaults write -g AppleLocale -string "$OLD_LOCALE"
    [ -n "$OLD_SHOWDATE" ] && defaults write com.apple.menuextra.clock ShowDate -int "$OLD_SHOWDATE"
    # `defaults read` returns 1/0 for a boolean, which `defaults write -bool`
    # will not accept back.
    if [ -n "$OLD_SHOWDOW" ]; then
        [ "$OLD_SHOWDOW" = "1" ] && v=true || v=false
        defaults write com.apple.menuextra.clock ShowDayOfWeek -bool "$v"
    fi
    killall ControlCenter 2>/dev/null
}
trap restore EXIT

# The menu bar clock is the one piece of chrome we cannot localise properly:
# AppleLocale fixes the 24h/AM-PM format, but the weekday and month names come
# from AppleLanguages, which only takes effect after a logout. Hiding the date
# sidesteps it - the remaining time reads correctly in both locales.
defaults write com.apple.menuextra.clock ShowDate -int 2
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false

# 11pt body text is unreadable once App Store Connect renders the shot as a
# thumbnail. Reverted by restore().
defaults write com.apple.TextEdit NSFixedPitchFontSize -int 22

# TextEdit covers everything below the menu bar, so the only thing that can
# bleed into a shot is the wallpaper behind the translucent menu bar - which
# on a photo wallpaper shows up as a smear across the top right.
"$HERE/pngtool" solid "$SHOT_W" "$SHOT_H" 14141C "$BG"
osascript -e "tell application \"System Events\" to set picture of every desktop to \"$BG\"" 2>/dev/null

pkill -x "Cursor Sightline" 2>/dev/null
sleep 1
"$HERE/setmode" "$SHOT_W" "$SHOT_H" || exit 1
sleep 2

# capture <name> <orientation> <readingLine> <thickness> <color> <cursorX> <cursorY>
capture() {
    local name="$1" orient="$2" reading="$3" thick="$4" color="$5" cx="$6" cy="$7"

    pkill -x "Cursor Sightline" 2>/dev/null
    sleep 1

    # Written while the app is down, so cfprefsd cannot overwrite them from a
    # live instance's in-memory copy.
    defaults write "$PREFS" orientation -string "$orient"
    defaults write "$PREFS" useReadingLine -bool "$reading"
    defaults write "$PREFS" thickness -float "$thick"
    defaults write "$PREFS" borderSize -float 1
    defaults write "$PREFS" opacity -float 0.9
    defaults write "$PREFS" crosshairColor -string "$color"
    defaults write "$PREFS" autoHideWhileTyping -bool false
    defaults write "$PREFS" hasCompletedFirstRun -bool true
    defaults write "$PREFS" language -string "$LOCALE"

    open -a "$APP" --args -fullAccessForScreenshots ${EXTRA:-}
    sleep 4

    # The settings window opens at 850x700 wherever macOS decides, which on an
    # 800-point-tall desktop runs off the bottom edge. Pin it instead.
    if [ -n "${EXTRA:-}" ]; then
        osascript <<EOF 2>/dev/null
tell application "System Events"
    tell process "Cursor Sightline"
        -- Not "window 1": the crosshair overlay is created first and owns that
        -- index, so moving it drags the drawn crosshair off the real cursor.
        set w to first window whose title is "$SETTINGS_TITLE"
        set position of w to {215, 45}
        set size of w to {850, 700}
    end tell
end tell
EOF
        sleep 1
    fi

    "$HERE/warpmouse" "$cx" "$cy"
    sleep 1

    # Every other app goes away last, so the shot is TextEdit plus the overlay
    # and nothing else. The shell keeps running while Terminal is hidden.
    # The name list is snapshotted first: hiding a process mutates the live
    # "every process whose visible is true" collection mid-loop, which aborts
    # the repeat and leaves whatever came after it on screen.
    osascript <<'EOF'
tell application "System Events"
    set targets to name of every process whose visible is true
end tell
repeat with n in targets
    if (n as text) is not "TextEdit" and (n as text) is not "Cursor Sightline" then
        try
            tell application "System Events" to set visible of process (n as text) to false
        end try
    end if
end repeat
EOF
    sleep 2

    "$HERE/warpmouse" "$cx" "$cy"
    # Kept short: the overlay tracks the real cursor, so any gap here is a
    # window in which a stray trackpad touch moves the crosshair off its mark.
    sleep 0.3
    screencapture -x -t png "$OUT/$name.png"

    # screencapture emits an alpha channel; App Store Connect rejects any
    # screenshot that carries one.
    "$HERE/pngtool" flatten "$OUT/$name.png" "$OUT/$name.png"

    osascript -e 'tell application "System Events" to set visible of process "Terminal" to true' 2>/dev/null
    sleep 1
    echo "captured $name"
}

shoot_locale() {
    LOCALE="$1"
    SETTINGS_TITLE="$2"
    local doc="$3"

    osascript -e 'tell application "TextEdit" to quit' 2>/dev/null
    sleep 1
    if [ "$LOCALE" = "en" ]; then
        defaults write com.apple.TextEdit AppleLanguages -array en
        defaults write -g AppleLocale -string "en_US"
    else
        defaults delete com.apple.TextEdit AppleLanguages 2>/dev/null
        defaults write -g AppleLocale -string "da_DK"
    fi
    # ControlCenter draws the clock and reads the locale only at launch.
    killall ControlCenter 2>/dev/null
    sleep 3

    # TextEdit is the backdrop for every shot: real text, so the reading line
    # and the crosshair have something to sit against.
    open -a TextEdit "$doc"
    sleep 3
    osascript <<'EOF'
tell application "TextEdit" to activate
delay 0.5
tell application "System Events"
    tell process "TextEdit"
        set position of window 1 to {0, 25}
        set size of window 1 to {1280, 775}
    end tell
end tell
EOF
    sleep 1

    # Cursor coordinates are in points on the 1280x800 desktop, measured off a
    # layout probe: text lines sit 25 points apart. Both documents use the same
    # line structure, so one set of coordinates serves both locales. The two
    # horizontal shots land in a gap between lines rather than through one, so
    # the line reads as a ruler instead of a strikethrough.
    EXTRA=""
    capture "$LOCALE-01-reading"   Horizontal true  4 "#FF3B30" 520 287
    capture "$LOCALE-02-crosshair" Both       false 3 "#FF3B30" 700 324
    capture "$LOCALE-04-circle"    Circle     false 3 "#30D158" 600 380

    # The appearance pane carries the upgrade story - six modes, own colours,
    # adjustable sizes - which none of the overlay shots can show on their own.
    EXTRA="-showSettingsForScreenshots"
    capture "$LOCALE-03-settings"  Both       false 3 "#FF3B30" 110 772
}

shoot_locale da "Indstillinger" "$HERE/readingtext_da.txt"
shoot_locale en "Settings"      "$HERE/readingtext_en.txt"

echo "--- results ---"
for f in "$OUT"/*.png; do
    printf "%s  " "$(basename "$f")"
    sips -g pixelWidth -g pixelHeight -g hasAlpha "$f" 2>/dev/null | tail -3 | tr -d '\n '
    echo
done
