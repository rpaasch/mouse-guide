# Cursor Sightline

En macOS-app der tegner et trådkors henover skærmen og følger musemarkøren.
Tænkt som hjælp til at finde markøren på store skærme og som læselineal når man
læser på skærmen.

Appen ligger i menulinjen og har intet Dock-ikon.

## Funktioner

**Seks visningstilstande**

| Tilstand | Beskrivelse |
|---|---|
| Vandret | Én vandret linje gennem markøren |
| Lodret | Én lodret linje gennem markøren |
| Begge | Fuldt trådkors (standard) |
| Læselinje | Ubrudt vandret linje uden centerhul — til læsning |
| Kantpile | Trekanter i skærmkanterne der peger mod markøren |
| Cirkel | Cirkel omkring markøren, med valgfri fyldfarve |

**Tilpasning** — farve på streg, kant og cirkelfyld; tykkelse, kantstørrelse,
centerhul, opacitet; hel, stiplet eller prikket linje; fuld skærmbredde eller
fast længde.

**Adfærd**
- Automatisk farvetilpasning: sampler baggrunden under markøren og skifter
  mellem lys og mørk streg (kræver Skærmoptagelse)
- Skjul mens du skriver, med justerbar forsinkelse
- Glidende markør (eksperimentel)
- Start ved login
- Multi-monitor: ét overlay pr. skærm, følger med når skærme tilsluttes

**Sprog** — dansk og engelsk, vælges automatisk efter systemsproget og kan
skiftes i Indstillinger.

## Tastaturgenvej

**⌃⇧L** (Control + Shift + L) slår trådkorset til og fra, uanset hvilket program
der er forrest. Genvejen kan ændres under Indstillinger → Adfærd → Aktivering.

Genvejen er registreret som systemgenvej (`RegisterEventHotKey`) og kræver ingen
tilladelser. Den tager kombinationen fra det program, der er forrest, så den
skal indeholde ⌘ eller ⌃ — ellers kunne den spærre for almindelig skrivning
(⌥2 er @ på et dansk tastatur).

## Pris

Appen er gratis, og alle funktioner er med. Den har ingen køb i appen og ingen
netværksadgang.

## Tilladelser

| Tilladelse | Bruges til | Påkrævet? |
|---|---|---|
| Skærmoptagelse | Automatisk farvetilpasning | Nej, kun til den funktion |

Appen beder ikke om Indtastningsovervågning eller Tilgængelighed. App Review
afviste i august 2026 en version, der lyttede til tastaturet (retningslinje
2.4.5). Skjul-mens-du-skriver læser nu kun, hvor længe siden der sidst blev
trykket på en tast — aldrig hvilken. Når farvetilpasning er slået til, kan status
for skærmoptagelse ses under Indstillinger → Om, hvorfra man også kan åbne
Systemindstillinger direkte.

Bemærk at macOS knytter tilladelser til appens placering. Flytter du appen
efter at have givet dem, skal de gives igen.

## Byg

Kræver Xcode 15 eller nyere. Appen kører på macOS 13 og opefter.

```bash
xcodebuild -project MouseGuide.xcodeproj -scheme MouseGuide -configuration Debug build
```

Eller åbn `MouseGuide.xcodeproj` i Xcode og tryk ⌘R.

## Projektstruktur

```
MouseGuide/
├── Sources/
│   ├── MouseGuideApp.swift           App-indgang og AppDelegate
│   ├── CrosshairsWindow.swift        Overlay-vinduer, tegning, muse-tracking
│   ├── CrosshairsSettings.swift      Indstillinger, standardværdier, gating
│   ├── SettingsView.swift            Indstillingsvindue (SwiftUI)
│   ├── MenuBarManager.swift          Menulinje
│   ├── KeyboardShortcutMonitor.swift Global genvejstast (systemgenvej)
│   ├── KeyboardShortcutRecorder.swift Optagelse af ny genvej
│   ├── LaunchAtLogin.swift           Login-element
│   ├── Localizable.swift             Lokaliseringshjælper
│   └── BuildInfo.swift               Version og byggeplacering
├── Resources/{en,da}.lproj/          Oversættelser
└── Info.plist
```

`scripts/audit_localization.py` finder ubrugte oversættelsesnøgler. Kør den
uden argumenter for en rapport, med `--apply` for at slette. Auditten er
nøglebaseret og medregner nøgler brugt som rå strengliteraler — en fejlagtigt
slettet nøgle fejler tavst og vises som nøglenavn i brugerfladen.

## Licens

Copyright © 2026 Rasmus Paasch.
