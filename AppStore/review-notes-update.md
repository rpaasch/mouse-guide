# App Review-noterne skal rettes før genindsendelse

Feltet *App Review Information → Notes* i App Store Connect indeholder stadig
svaret fra 17. august (`review-reply-short.txt`). To afsnit i det beskriver
Input Monitoring, som appen ikke længere beder om. Står de der stadig, siger
noterne det modsatte af svaret til App Review (`review-reply-2.4.5.txt`).

Erstat de to afsnit herunder. Resten af noterne kan blive stående.

## 1. Under "1. Screen recording"

Erstat afsnittet, der begynder med *"Two items from your list are not in it."*, med:

```
The recording shows where the purchase is offered but does not complete one. We can record the full purchase flow on request. The app no longer shows any permission prompt at launch.
```

## 2. Under "4."

Erstat *"Two optional permissions are requested …"* og de to punkter under det med:

```
The app requests no permissions to run. Control-Shift-L is a system hot key and works in every app without any permission. "Hide while typing" only reads how long ago a key was last pressed, never which key.

One optional permission can be requested: Screen Recording, and only when the user turns on automatic color adaptation. It is used to sample the brightness under the pointer so the crosshair can switch between a light and a dark line. Nothing is recorded, stored or transmitted.
```

## Også i App Store Connect

Beskrivelsen af listingen (da + en-US) har stadig den gamle sætning under
PRIVATLIV / PRIVACY om Input Monitoring. De nye tekster står i `da-DK.md` og
`en-US.md`.
