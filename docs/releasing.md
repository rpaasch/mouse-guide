# Releasing Cursor Sightline to the Mac App Store

## The rule that got us

**Archive on a released macOS. Never on a seed.**

Build 9 was rejected with:

> ITMS-90301: This bundle is invalid - Apple is not currently accepting
> applications built with this version of the OS.

The toolchain was not the problem. Build 9 used Xcode 26.6 (`DTXcodeBuild
17F113`) and the macOS 26.5 SDK (`DTSDKBuild 25F70`) — both released. What
failed was `BuildMachineOSBuild = 26A5388g`, the *host* OS, a macOS 27.0 seed.
Xcode stamps the machine's OS build into every app it archives, and Apple
rejects prerelease values. No choice of Xcode changes this; only the machine
does.

Two things make this expensive to get wrong:

- The check runs **server-side during processing**, after upload.
  `xcodebuild -exportArchive` and `altool --validate-app` both pass happily on
  a doomed build. A clean local validation is not evidence.
- A rejected build number is spent. Bump `CFBundleVersion` before re-archiving.

## Doing a release

On a Mac booted from a **released** macOS, with Xcode 26.6 installed:

```sh
scripts/archive_release.sh            # archive + verify + export
scripts/archive_release.sh --upload   # ... and upload
```

`--smoke-test` rehearses everything short of Apple: it downgrades the two OS
gates to warnings, archives, verifies, and stops before export. It was run on
the seed machine and passed, so the archive step, signing, the metadata reads
and the build-number check are all known-good; the only value that differs on a
released machine is `BuildMachineOSBuild`.

The script refuses to archive on a seed OS, and re-reads the
`BuildMachineOSBuild` actually stamped into the built binary before it will
export or upload — so it fails on the machine rather than at Apple.

It reads the build number from `MouseGuide/Info.plist`, picks the newest
non-beta `/Applications/Xcode*.app` (override with `DEVELOPER_DIR`), and
invokes that Xcode's own `xcodebuild` binary directly — which sidesteps the
license check that blocks `/usr/bin/xcodebuild` when `xcode-select` points
elsewhere.

App Store Connect credentials default to key `Y55Q877P98` / issuer
`69a6de73-…`, read from `~/.appstoreconnect/private_keys/`. Override with
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`.

## Xcode Cloud — the way out without hardware

Xcode Cloud builds on Apple-managed images running *released* macOS, so the
seed-OS problem disappears entirely: no external SSD, no second Mac, no disk
space. This is the recommended route.

Onboarding cannot be scripted. `POST /v1/ciProducts` answers:

> 403 — The resource 'ciProducts' does not allow 'CREATE'.
> Allowed operations are: DELETE, GET_COLLECTION, GET_INSTANCE

`ciWorkflows` and `ciBuildRuns` *do* allow creation (they fail with
`ENTITY_ERROR.*` for missing fields, not with a forbidden-operation error), so
only the first step needs a human:

**One-time, in Xcode:** Product → Xcode Cloud → Create Workflow → select
Cursor Sightline → grant access to the `rpaasch/mouse-guide` repository →
Archive action for macOS → deploy to App Store Connect.

Use **Xcode 27 Beta 4** for this, which is already installed. The App Store
refuses to install Xcode 26.6 on a macOS 27 seed ("this version of Xcode is not
supported in this version of macOS"), but the local Xcode version is irrelevant
to Xcode Cloud — the workflow decides what Apple's builders use.

Set the workflow to:

| Setting | Value | Why |
|---|---|---|
| macOS | **Latest Release** (25G82, Tahoe 26.6.2) | Released, so `BuildMachineOSBuild` is clean |
| Xcode | **Latest Release** (17F113) | Identical to the toolchain build 9 used |

Do *not* pick "Latest Beta or Release" for macOS. It resolves to the same 25G82
today, but will drift onto a seed later and reintroduce ITMS-90301.

Apple's own image catalogue corroborates the diagnosis, incidentally:
`/v1/ciMacOsVersions` lists `26A5388g` — this Mac's OS — as
"macOS Golden Gate 27 beta 4".

Note that the GitHub connection already exists as an SCM provider, but it is
currently scoped to the `netdotrss` repository only — `mouse-guide` has to be
granted during the wizard.

**Prerequisite, already done:** Xcode Cloud only builds *shared* schemes. This
project had none at all — `xcodebuild` was synthesising one from the target,
which works locally but leaves nothing in the repo for Apple's builders.
`MouseGuide.xcscheme` is now committed under
`MouseGuide.xcodeproj/xcshareddata/xcschemes/`.

After the product exists, workflows and build runs can be driven entirely
through the API. The handles, so a release does not mean rediscovering them:

| | |
|---|---|
| App | `6800107419` (`dk.netdot.sightline.app`) |
| Xcode Cloud product | `575adf31-8e83-4d65-9aca-b271ba9eed33` |
| Workflow "Release - App Store" | `19e35c04-5386-447e-a5c9-76f6dbec54b6` |
| Workflow "Default" (build only) | `3293325C-FD58-4D29-A045-1D57BF010BA0` |
| Repository `mouse-guide` | `090247ff-4d8c-4149-bec3-f1f264b9b785` |
| Branch `main` | `6309026e-8aa5-41b0-b177-0c79a8b9f65a` |

Start a release with `POST /v1/ciBuildRuns`, relating the release workflow and
that branch reference.

**The build number comes from Xcode Cloud, not from `Info.plist`.** It is the
product's run counter, assigned at delivery, and a `ci_scripts` hook cannot
change it (that was tried and reverted). The counter is *shared across the
product's workflows*, so a run of the build-only workflow advances it without
delivering anything — which is how build 10 was lifted clear of the already-used
8 and 9. Build runs cannot be cancelled through the API (403).

## Standing decisions — do not "fix" these

**Territory availability: Belarus and Russia are excluded on purpose.** App
Availability reads "173 Available, 2 Not Available", and those two are a
deliberate choice, not an oversight and not an Apple restriction. The App Store
still operates in both, so both remain selectable — Apple's 2022 withdrawal from
Russia covered hardware sales and Apple Pay, not App Store distribution. Leave
the exclusion alone unless the decision is revisited.

(The purchase, by contrast, is set to all 175 territories. The app's narrower
list is what governs where it can actually be bought.)

## Submitting an in-app purchase for review

The first in-app purchase must be reviewed together with an app version —
App Store Connect says so on the version page, and `POST
/v1/inAppPurchaseSubmissions` refuses a standalone first purchase with
`STATE_ERROR.INVALID_REQUEST_ENTITY_STATE_INVALID`.

The API can do it, but the relationship is easy to get wrong. On
`reviewSubmissionItems` it is **`inAppPurchaseVersion`**, pointing at the record
under `/v2/inAppPurchases/{id}/versions` — *not* at the purchase itself.
`inAppPurchase`, `inAppPurchaseV2` and `inAppPurchases` are all rejected as
unknown relationships. So:

1. `POST /v1/reviewSubmissions` — app relationship, `platform: MAC_OS`
2. `POST /v1/reviewSubmissionItems` — `appStoreVersion` → the version
3. `POST /v1/reviewSubmissionItems` — `inAppPurchaseVersion` → the purchase's
   version record
4. Check the submission has **2 items**, then `PATCH … {"submitted": true}`

Items cannot be added once submitted; the only way back is Cancel Submission,
which puts the version into `DEVELOPER_REJECTED` (a normal state, not an error)
and costs the place in the review queue.

## Getting a released-macOS machine

The dev Mac runs macOS 27.0 seed and has no second system volume. Options:

- **External SSD** — install macOS 26.x on it, plus Xcode 26.6, and boot from
  it to release.
- **A second Mac** on a released OS.
- **A second internal volume** is *not* currently viable: only ~26 GB free on
  the internal disk, and macOS 26.x plus Xcode 26.6 needs appreciably more.

### What has to travel to that machine

Booting another volume means a different login keychain and a different home
directory. Three things must arrive:

1. **The repo, via `git push`.** Route A only works if build 10, this doc,
   `scripts/archive_release.sh` and `scripts/ExportOptions.plist` are on
   `origin/main` — otherwise the release machine clones a tree that still says
   build 9. The build scheme needs no special handling: no `.xcscheme` file
   exists in the project, so `xcodebuild` synthesises it from the target
   deterministically on any machine.
2. **`AuthKey_Y55Q877P98.p8` → `~/.appstoreconnect/private_keys/`.** The
   script defaults to that path and it will not exist on a fresh volume.
3. **Nothing else, most likely.** This Mac holds *no* Mac App Store
   distribution certificate — `security find-identity -v` lists only
   "Apple Development: Rasmus Paasch". There is no `.p12` to export. The
   script passes `-allowProvisioningUpdates` with the API key to both `archive`
   and `-exportArchive`, so distribution signing assets get fetched or minted
   on demand. Copying
   `~/Library/Developer/Xcode/UserData/Provisioning Profiles/58d2b819-*.provisionprofile`
   across is harmless insurance but should not be needed.

Be aware that minting distribution certificates consumes the team's limited
slots, which is why `--smoke-test` deliberately stops before export.

## After a build processes cleanly

1. Link build to version 1.0 in App Store Connect.
2. Complete the App Privacy questionnaire (see below).
3. Submit for review.

## App Privacy — has to be done by hand

There is no API for this. The public App Store Connect API exposes no
privacy-related resource on the `apps` endpoint, and the internal route the web
UI uses (`appstoreconnect.apple.com/iris/v1/appDataUsages`) answers an API-key
JWT with `401 No valid credentials` — it accepts only an interactive login
session. It must be clicked through in the browser:

> App Store Connect → Apps → Cursor Sightline → **App Privacy** (left sidebar)
> → Data Collection → Edit → **"No, we do not collect data from this app"**
> → Save → **Publish**

The declaration does not go live until Publish is pressed, and version 1.0
cannot be submitted for review until it has.

"Data not collected" is accurate for this app, verified against the source:

- No networking, analytics or tracking code of any kind. The only
  `com.apple.security.network.client` use is StoreKit product lookup and
  purchase; `StoreKitManager.swift` makes no calls of its own.
- Input monitoring and screen capture are processed locally and never stored or
  transmitted — they read keystroke events and sample pixel brightness under
  the cursor.
- Preferences and the trial flag are stored locally (UserDefaults /
  Application Support).
- Purchase data is collected by Apple, not by us, so it is not declarable here.

This matches `PRIVACY.md`.
