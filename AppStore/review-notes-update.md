# App Review-noterne skal rettes før genindsendelse

Feltet *App Review Information → Notes* i App Store Connect indeholder stadig
svaret fra 17. august (`review-reply-short.txt`). Fire afsnit i det beskriver
Input Monitoring og købet i appen, som begge er væk. Står de der stadig, siger
noterne det modsatte af svaret til App Review (`review-reply-2.4.5.txt`).

Erstat de fire afsnit herunder. Resten af noterne kan blive stående.

## 1. Under "1. Screen recording"

Erstat afsnittet, der begynder med *"Two items from your list are not in it."*, med:

```
The recording from 17 August still shows how the app works, except for the License pane, which has been removed. The app no longer shows any permission prompt at launch. We can send a new recording on request.
```

## 2. Under "4."

Erstat *"Two optional permissions are requested …"* og de to punkter under det med:

```
The app requests no permissions to run. Control-Shift-L is a system hot key and works in every app without any permission. "Hide while typing" only reads how long ago a key was last pressed, never which key.

One optional permission can be requested: Screen Recording, and only when the user turns on automatic color adaptation. It is used to sample the brightness under the pointer so the crosshair can switch between a light and a dark line. Nothing is recorded, stored or transmitted.
```

## 3. Under "5. External services, tools and platforms"

Erstat hele afsnittet med:

```
None. Apple frameworks only: SwiftUI, AppKit, Carbon and Core Graphics. No server, analytics, tracking, authentication service, AI service or payment processor. The app has no network access; it does not have the network client entitlement.
```

## 4. Under "8. What the in-app purchase provides, and how to reach it"

Erstat overskriften og hele afsnittet med:

```
8. In-app purchases

None. The app is free, and every feature is available without payment.
```

## Også i App Store Connect

- **Købet:** tages ud af indsendelsen og slettes.
- **Beskrivelsen (da + en-US):** afsnittene om pris og privatliv skal opdateres.
  De nye tekster står i `da-DK.md` og `en-US.md`.
- **Skærmbilleder:** `da-03-settings.png` og `en-03-settings.png` viser Licens-fanen
  og skal tages om og uploades igen.
