# Mouse Guide — oprydning og ny licensmodel

**Dato:** 2026-08-10
**Branch:** `cleanup/loose-ends-and-license-model`

## Formål

Rydde op i løse ender fundet ved gennemlæsning af hele kodebasen, og samtidig
lægge licensmodellen om fra tidsbaseret trial til permanent freemium. De to ting
hører sammen: modellen ligger opstrøms for strengoprydningen, så gøres de hver
for sig, ryddes der op i strenge der straks efter skal slettes.

## Trufne beslutninger

| Emne | Valg |
|---|---|
| Distribution | Kun Mac App Store |
| Licensmodel | Gratis app med ét permanent IAP-unlock. Ingen trial, ingen tidsgrænser |
| Gratis/Pro-snit | Gratis = én fast standardvisning. Pro = tilpasning + flere skærme |
| Gratis-visning | 2px streg, 1px kant, 10px centerhul, opacitet 1.0, låst `.both` + `.solid` |
| `autoHideWhenPointerHidden` | Implementeres |
| `DiagnosticsManager` | Slettes |
| `UpdateChecker` | Slettes (App Store håndterer opdateringer) |
| Docs | README omskrives; `build.sh` og `INSTALLATION_GUIDE.md` slettes |
| Strengoprydning | Nøglebaseret audit, aggressiv sletning |
| Verifikation | Manuel, mod navngivet tjekliste |

## 1. Licensmodel

`LicenseManager.swift` slettes helt. Uden trial og free-session er der kun ét
spørgsmål — købt eller ej — og `StoreKitManager` svarer allerede på det.

Bortfalder: `LicenseState` (5 tilstande), `TrialData`, `trial.json` og
`~/Library/Application Support/com.mouseguide/`, `freeTimer`,
`trialDaysRemaining`, `freeMinutesRemaining`, `freeSecondsRemaining`,
`startFreeSession()`, `resetTrial()`.

Følgerydning i `MouseGuideApp.swift`: `handleFreeSessionExpiry()`,
`showFreeSessionExpiryDialog()`, `restartApp()`, `sessionExpiryWindow`,
`sharewareWindow`, `FreeSessionExpired`-observeren.

I `SettingsView.swift`: `LicenseTab` reduceres til tre tilstande (købt / ikke
købt / tjekker); de to `#if DEBUG`-testknapper fjernes.

Adgangstjek:

```swift
var hasFullAccess: Bool {
    UserDefaults.standard.bool(forKey: Self.purchaseCacheKey)
}
```

**Afvigelse fra oprindeligt design:** specen foreslog
`StoreKitManager.shared.isPurchased || cachedPurchase`. Implementeret som ren
cache-læsning i stedet, fordi `StoreKitManager` er `@MainActor` mens
`hasFullAccess` kaldes fra tegnekoden hver frame. Cachen skrives synkront i
`purchaseState.didSet` før notifikationen udsendes, så den er altid mindst lige
så frisk som StoreKit selv — det ekstra led gav ingen friskhed, kun en
aktørgrænse at krydse.

**Kendt afvejning:** flaget kan sættes med `defaults write`, så adgangen er
teknisk omgåelig. Accepteret bevidst — det gælder også den nuværende kode, og
prisen for alternativet er et synligt hop ved opstart.

`StoreKitManager` poster `PurchaseStateChanged` ved ændring;
`CrosshairsWindowManager` lytter på den i stedet for `LicenseStateChanged`.

### Gratis-visning

`effective*`-properties når der ikke er købt:

| Egenskab | Værdi |
|---|---|
| `effectiveThickness` | 2.0 |
| `effectiveBorderSize` | 1.0 |
| `effectiveCenterRadius` | 10.0 |
| `effectiveOpacity` | 1.0 |
| `effectiveCrosshairColor` | rød |
| `effectiveBorderColor` | sort |
| `effectiveOrientation` | `.both` (låst) |
| `effectiveLineStyle` | `.solid` (låst) |
| `effectiveInvertColors` | false |
| Skærme | kun hovedskærm |

Kanten på 1px er ikke til forhandling: uden den forsvinder en rød streg på rød
eller mørk baggrund, og målgruppen er folk der har svært ved at se ting på
skærmen. Orientering og linjestil låses til faste værdier frem for "sidst
valgte", så en bruger ikke sidder fast i f.eks. cirkeltilstand.

## 2. Adfærdsrettelser

**Menugenvej.** `MenuBarManager.updateShortcutDisplay()` hardkoder `"l"` +
`[.shift, .control]`; skal læse `settings.activationKey` /
`activationModifiers`. Betingelsen `keyboardShortcutMonitor != nil` er altid
sand (monitoren oprettes uanset tilladelse), så menuen reklamerer med en genvej
der ikke virker; erstattes af `settings.hasInputMonitoringPermission()`.
`AppDelegate.canShowShortcutInMenu` udgår.

**`resetToDefaults()`.** Mangler i dag syv indstillinger. Årsagen er strukturel:
funktionen sætter alle properties og gentager derefter et `saveSetting(...)` for
hver — men hver `@Published` har allerede et `didSet` der gemmer. To lister der
skal holdes i sync. Rettelse: ét `Defaults`-sæt af konstanter som både `init` og
`resetToDefaults()` læser fra, og den duplikerede save-blok slettes. `language`
nulstilles bevidst ikke.

**Fundet undervejs:** samme omskrivning afdækkede at `init` læste tal med
`UserDefaults.double(forKey:)`, som returnerer 0 for en manglende nøgle. En
gemt 0 (kantstørrelse, centerradius — begge lovlige værdier i UI'ets
skydere) var derfor ikke til at skelne fra "ikke sat" og blev tavst skiftet
tilbage til standardværdien ved næste opstart. Rettet ved at læse gennem
`object(forKey:) as? Double`.

**`autoHideWhenPointerHidden`.** Der bliver nu to uafhængige grunde til at skjule
vinduerne. En parallel toggle ville få dem til at vise hinanden frem igen og
arve det positionshop som `unhideAfterTyping()` findes for at undgå. Derfor
samles synligheden ét sted:

- `hiddenByTyping`, `hiddenByPointerHidden` — uafhængige flag
- `shouldBeVisible` — afledt
- `applyVisibility()` — eneste sted der kalder `orderOut`/`orderFrontRegardless`,
  reagerer kun på faktisk tilstandsskift, og ejer nulstillingen af
  `mouseTracker.position`, `targetPosition`, `isFirstFrame`, `lastUpdateTime`
- `updateCursorPosition()` early-returner på faktisk synlighed

Detektion kræver ingen ny timer; i den eksisterende 60 Hz-løkke:
`hiddenByPointerHidden = settings.autoHideWhenPointerHidden && NSCursor.currentSystem == nil`.

**Risiko:** `NSCursor.currentSystem == nil` er en heuristik, ikke et dokumenteret
API for "markøren er skjult". Slår den fejl, ender vi med præcis den fejl vi
retter — en kontakt der intet gør. Skal verificeres mod navngivne scenarier.

## 3. Sletninger

Filer (inkl. `project.pbxproj`-poster): `UpdateChecker.swift`,
`DiagnosticsManager.swift`, `LicenseManager.swift`, `build.sh`,
`INSTALLATION_GUIDE.md`.

Symboler: `ShortcutsTab`, `SliderRow`, `SettingRow`, `String.appendToFile`,
`BuildInfo.generateBuildInfoString()`,
`KeyboardShortcutMonitor.showPermissionNotification()` (+ dens flag),
`CrosshairsSettings.hasSeenSharewareReminder`.

## 4. Strengoprydning

Audit skal være **nøglebaseret, ikke accessor-baseret** — `commonOK` og
`commonOk` peger begge på `"common.ok"`, så accessor-tælling ville markere den
nøgle som død.

1. Parse `Localizable.swift` til accessor → nøgle
2. `usedKeys` = nøgler for accessors brugt i øvrige kildefiler **∪** nøgler fra
   rå `"…".localized()`-literaler (i dag de fire `settings.category.*`)
3. `deadKeys` = nøgler i `en.lproj` − `usedKeys`
4. Slet fra **begge** `.strings`-filer og fra `Localizable.swift`
5. Assertér at de to filer har identiske nøglesæt

Trin 2 og 5 er det der gør sletningen sikker. Uden trin 2 slettes fire levende
nøgler; uden trin 5 kan filerne drifte fra hinanden. En forkert slettet nøgle
fejler **tavst** — `.localized()` returnerer nøglenavnet, så brugeren ser
`"about.reset.button"` som synlig tekst.

Udgangspunkt før modelændringen: 87 af 309 accessors ubrugte; 313 nøgler i hver
fil.

Ud over de i specen nævnte gates blev også `effectiveUseFixedLength` og
`effectiveUseReadingLine` tilføjet: begge var brugerindstillinger som
tegnekoden læste direkte, og som derfor kunne ændre gratis-visningen.

## 5. Dokumentation

README omskrives: hvad appen er, korrekt genvej (⇧⌃L), alle seks tilstande,
nødvendige tilladelser, byg med
`xcodebuild -project MouseGuide.xcodeproj -scheme MouseGuide`.
`build.sh` (peger på et projektnavn der ikke findes) og `INSTALLATION_GUIDE.md`
slettes.

Modelændringen gjorde desuden App Store-teksterne forkerte: `AppStore/metadata.txt`,
`AppStore/en-US.md` og `AppStore/da-DK.md` lovede alle "7 dages prøveperiode".
Afsnittet er erstattet af en beskrivelse af gratis/fuld-modellen på begge sprog.
Strengen `license.freeRestrictions` lovede tilsvarende "1px" og "genstart hvert
10. minut" og er omskrevet i begge `.strings`-filer.

## 6. Verifikation

Manuel, ingen testmål. Baseline-build bekræftet grøn før ændringer.

**Markør-skjult — navngivne scenarier** (kritisk, heuristik):
1. Fuldskærms-videoafspilning i QuickTime — markør auto-skjules efter ~3 sek
2. Keynote i præsentationstilstand
3. Skriv i et tekstfelt hvor macOS skjuler markøren mens man taster
4. Slå indstillingen fra igen — trådkorset må ikke blive væk

**Synlighed må ikke konflikte:** slå både "skjul mens du skriver" og
"skjul når markør er skjult" til; tast i fuldskærmsvideo; trådkorset skal komme
tilbage præcist én gang, uden positionshop.

**Øvrigt:**
- Genvej ændret i Indstillinger → menuen viser den nye genvej
- Input Monitoring nægtet → menuen viser ingen genvej
- Nulstil → alle indstillinger inkl. linjestil, cirkelradius, kantpiletykkelse,
  læselinje; sprog uændret
- Gratis-visning: 2px rød streg med sort kant, synlig på hvid, sort og rød
  baggrund; kun hovedskærm
- Køb → alle Pro-sektioner låses op uden genstart; Gendan køb virker
- Skift sprog da/en → ingen synlige nøglenavne nogen steder i UI'et
