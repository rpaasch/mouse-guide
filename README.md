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

**⇧⌃L** (Shift + Control + L) slår trådkorset til og fra. Genvejen kan ændres
under Indstillinger → Adfærd → Aktivering.

Genvejen kræver tilladelsen Indtastningsovervågning. Uden den virker den ikke,
og menulinjen viser den derfor ikke — brug menupunktet i stedet.

## Gratis og fuld version

Appen er gratis at bruge. Gratis-versionen viser ét fast trådkors: 2px rød
streg med sort kant, begge retninger, på hovedskærmen.

Køb i appen (Indstillinger → Licens) låser op for tilpasning — alle seks
tilstande, frie farver og dimensioner, linjestil, automatisk farvetilpasning og
visning på alle skærme. Det er et engangskøb; køb kan gendannes på andre
maskiner med samme Apple-konto.

## Tilladelser

| Tilladelse | Bruges til | Påkrævet? |
|---|---|---|
| Indtastningsovervågning | Tastaturgenvej, skjul-mens-du-skriver | Nej, kun til de funktioner |
| Skærmoptagelse | Automatisk farvetilpasning | Nej, kun til den funktion |

Ingen af dem er nødvendige for at vise trådkorset. Status kan ses under
Indstillinger → Om, hvorfra man også kan åbne Systemindstillinger direkte.

Bemærk at macOS knytter tilladelser til appens placering. Flytter du appen
efter at have givet dem, skal de gives igen.

## Byg

Kræver Xcode 15 eller nyere. Appen kører på macOS 13 og opefter.

```bash
xcodebuild -project MouseGuide.xcodeproj -scheme MouseGuide -configuration Debug build
```

Eller åbn `MouseGuide.xcodeproj` i Xcode og tryk ⌘R.

Køb testes lokalt gennem `MouseGuide/MouseGuideProducts.storekit` — vælg
StoreKit-konfigurationen i schemets Run-indstillinger.

## Projektstruktur

```
MouseGuide/
├── Sources/
│   ├── MouseGuideApp.swift           App-indgang og AppDelegate
│   ├── CrosshairsWindow.swift        Overlay-vinduer, tegning, muse-tracking
│   ├── CrosshairsSettings.swift      Indstillinger, standardværdier, gating
│   ├── SettingsView.swift            Indstillingsvindue (SwiftUI)
│   ├── MenuBarManager.swift          Menulinje
│   ├── KeyboardShortcutMonitor.swift Global genvejstast
│   ├── KeyboardShortcutRecorder.swift Optagelse af ny genvej
│   ├── StoreKitManager.swift         Køb og gendannelse
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
