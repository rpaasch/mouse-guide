# Wider

Safari extension for iPhone that lets websites use the full front screen,
including the space beside Safari's controls.

## How it works

The whole effect is one change to the page's viewport tag: Wider adds
`viewport-fit=cover`, so Safari lays the page out across the full screen
instead of stopping at the safe area. Turning it off puts back exactly what the
page had.

- Pages with a viewport tag get `viewport-fit=cover` added to it.
- Pages without one get a tag with only `viewport-fit=cover`. Wider does not add
  `width=device-width`, because that would make desktop pages switch to a mobile layout.
- Pages that rewrite their tag later (single-page apps) get widened again, and
  what they wrote is what gets restored.

Sites with fixed headers or their own layout limits may still not widen cleanly.
That depends on the site's CSS.

## Settings

Kept in the extension's `storage.local`. Nothing leaves the device.

- Every site starts wide. The round button in the popup switches a site between
  wide and normal, and that choice is saved by hostname.
- "Off on this page" turns off a single page (origin + path, query and hash
  ignored).
- "Report this site" opens a mail with that page's URL and nothing else. The app
  can do the same for a URL that is typed in. The address is `REPORT_ADDRESS` in
  `popup.js` and `reportAddress` in `ContentView.swift`.

The extension asks only for `storage`. It has no `tabs` permission, so the
popup gets the page URL from the content script.

## Layout

```
project.yml                 XcodeGen spec -> Wider.xcodeproj
App/                        SwiftUI container app: setup steps, report a site
Extension/
  SafariWebExtensionHandler.swift
  Resources/                the web extension (manifest v3)
    settings.js             storage and the wide/normal rule, shared
    content.js              the viewport change
    popup.*                 the toolbar popup
    _locales/{en,da}
scripts/icon.svg            source for every icon
scripts/render_icons.js     renders the PNGs
tests/run.js                runs content script and popup in Chromium
```

## Build

```sh
brew install xcodegen
cd Wider
xcodegen generate
open Wider.xcodeproj
```

Run the Wider scheme on a device. Then open Settings → Apps → Safari →
Extensions, turn on Wider, and allow it for all websites in Safari's extensions
menu.

## Test

```sh
cd Wider
node tests/run.js          # needs Playwright and Chromium
node scripts/render_icons.js   # after changing scripts/icon.svg
```
