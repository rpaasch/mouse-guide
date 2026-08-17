# Reply to App Review — Guideline 2.1, Information Needed

Submission ID 6fba4fbc-5ac1-4c74-bee5-80daf462acd9 · version 1.0 (build 10)

Paste the text below into the App Review page in App Store Connect, and attach
the screen recording. No resubmission is needed — Apple's notice says so
explicitly: *"you don't need to resubmit your app. Simply make the changes and
send us a message from the App Review page when you're done."*

The one thing that cannot be written: **item 1 is a screen recording** and has
to be made on the Mac. Everything else is answered below.

---

Hello,

Thank you for the review. Answers to each point follow, and a screen recording
is attached.

**1. Screen recording**

Attached. It was captured on a MacBook Pro (Mac15,6, Apple M3 Pro) and shows,
in order: launching the app, the menu bar icon appearing, turning the crosshair
on, the crosshair following the pointer, opening Settings, switching display
modes and colours, the two permission prompts, and the in-app purchase flow
including the App Store payment sheet.

**2. Devices and operating systems tested**

MacBook Pro 14-inch (Mac15,6, Apple M3 Pro) running macOS 27.0.
The app's deployment target is macOS 13.0.

**3. What the app does, and for whom**

Cursor Sightline draws a crosshair that follows the mouse pointer, so the
pointer can be located at a glance. It is a menu bar utility: it has no Dock
icon and opens no window at launch.

It is for people who lose track of the pointer — users with reduced vision,
anyone working on a large or multi-monitor setup, and people presenting or
teaching, where an audience needs to see where the pointer is. The problem it
solves is simple and constant: on a big, bright screen a small arrow is easy to
lose, and hunting for it interrupts whatever the user was doing.

There are six display modes — horizontal line, vertical line, full crosshair,
reading line (an unbroken horizontal line without a centre gap, for following
text), edge pointers (triangles at the screen edges pointing toward the
cursor), and a circle around the cursor. Colour, thickness, border, centre gap,
opacity, line style and length are adjustable. The crosshair can hide itself
while typing, and can adapt its colour to the background under the pointer.

**4. Setting up and reaching the main features**

No account, login or sample files are required. There is nothing to configure
before the app works.

1. Launch the app. It appears as a crosshair icon in the menu bar at the top
   right — there is no Dock icon and no window.
2. Click the menu bar icon and choose "Show Cursor Sightline", or press
   Control-Shift-L. The crosshair appears and follows the pointer.
3. Choose "Settings" in the same menu to change mode, colour, size and
   behaviour.

Two optional permissions are requested, and the app is fully usable if both are
declined:

- **Input Monitoring** — so the Control-Shift-L shortcut works globally, and so
  the crosshair can hide itself while the user types. Declining it means the
  shortcut does not work; the menu bar item still does.
- **Screen Recording** — used only to sample the brightness of the screen area
  under the pointer, so the crosshair can switch between a light and a dark
  line automatically. Nothing is recorded, stored or transmitted. Declining it
  means the colour stays as configured.

**5. External services, tools and platforms**

None. The app uses only Apple frameworks — SwiftUI, AppKit, Core Graphics and
StoreKit for the in-app purchase. There is no server, no analytics, no
tracking, no authentication service, no payment processor other than Apple's,
and no AI service. The app makes no network connections of its own; the
`com.apple.security.network.client` entitlement is present solely because
StoreKit requires it to look up and complete the purchase.

**6. Regional differences**

None. The app behaves identically in every region. The interface is available
in English and Danish and follows the system language; there is no difference
in features, content or pricing behaviour between regions.

**7. Regulated industries or third-party material**

Not applicable. The app is a cursor visibility utility. It operates in no
regulated industry and contains no third-party or protected material — all
code, graphics and text are our own.

**8. What the in-app purchase provides, and how to reach it**

There is one non-consumable in-app purchase, "Full Version"
(`dk.netdot.sightline.fullversion`). There is no subscription and no time
limit.

The app is free and fully functional without it: it shows a fixed red crosshair
with a thin black border on the main screen, so a user who never buys anything
can still find the pointer. The purchase unlocks customisation — all six
display modes, custom colours for line, border and circle fill, adjustable
thickness, border, centre gap, opacity and length, solid/dashed/dotted line
styles, automatic colour adaptation, and support for all connected displays
rather than the main one only.

To reach it: click the menu bar icon → **Settings** → **License** in the
sidebar → **Buy Now**. The locked settings elsewhere in Settings also link to
the same place.

Please let us know if anything else would help.

Best regards,
Rasmus Paasch
