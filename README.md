# Mouse Guide for macOS

En macOS-app der efterligner Microsoft PowerToys' "Mouse Pointer Crosshairs" funktion.

## Funktioner

- **Crosshairs overlay**: Tegner et trådkors centreret på musemarkøren
- **Fuldskærm support**: Akserne strækker sig til skærmens kanter på alle skærme
- **Multi-monitor support**: Virker på tværs af flere skærme
- **Tastaturgenvejer**: Tænd/sluk crosshairs med en tilpasselig genvej (standard: ⌘⇧C)
- **Tilpasning**: Mange indstillingsmuligheder for udseende og opførsel
- **Flersproget**: Support for dansk og engelsk, følger automatisk systemsproget
- **Onboarding**: Tydelig introduktion ved første opstart med vejledning til brug og opsætning

## Indstillinger

### Udseende
- **Farve**: Vælg farve på crosshairs
- **Kantfarve**: Vælg farve på kanten
- **Gennemsigtighed**: 0-100% (standard: 75%)
- **Centerradius**: Mellemrum omkring markøren (standard: 20px)
- **Tykkelse**: Linjens tykkelse (standard: 5px)
- **Kantstørrelse**: Kantens størrelse i pixels

### Orientering
- Vandret
- Lodret
- Begge (standard)

### Længde
- **Fast længde**: Brug en fast længde i stedet for fuldskærm
- **Fast længde (px)**: Længden når fast længde er aktiveret

### Adfærd
- **Skjul automatisk**: Skjul crosshairs når musemarkøren er skjult

### Gliding Cursor (eksperimentel)
- **Hastighedsindstilling**: Kontroller hvor hurtigt markøren glider
- **Forsinkelsesindstilling**: Forsinkelse før gliding starter

## Installation

1. Åbn projektet i Xcode
2. Byg og kør projektet (⌘R)
3. Appen vil vises i menu bar
4. Ved første kørsel vises onboarding guiden der hjælper dig med at:
   - Forstå funktionerne
   - Give nødvendige systemtilladelser (Accessibility)
   - Komme i gang med at bruge appen

## Brug

1. Klik på app-ikonet i menu bar
2. Vælg "Toggle Crosshairs" eller brug tastaturgenvejen (⌘⇧C)
3. Juster indstillinger via "Settings..."

## Sprog

Appen understøtter følgende sprog:
- Engelsk (English)
- Dansk (Danish)

Sproget vælges automatisk baseret på dit systems sprogindstillinger.

## Tilgængelighed

For at bruge globale tastaturgenveje kræver appen Accessibility-tilladelse. Du bliver guidet til at give denne tilladelse ved første opstart.

Gå til: **Systemindstillinger → Privatliv og sikkerhed → Tilgængelighed**

## Systemkrav

- macOS 13.0 eller nyere
- Xcode 15.0 eller nyere for at bygge

## Projektstruktur

```
MouseCrosshairs/
├── Sources/
│   ├── MouseCrosshairsApp.swift      - Hovedapp og AppDelegate
│   ├── CrosshairsWindow.swift        - Overlay vindue der tegner crosshairs
│   ├── CrosshairsSettings.swift      - Indstillinger med persistence
│   ├── SettingsView.swift            - Indstillings UI
│   ├── OnboardingView.swift          - Introduktionsguide
│   ├── Localizable.swift             - Lokaliserings hjælper
│   ├── KeyboardShortcutMonitor.swift - Global keyboard shortcut
│   └── MenuBarManager.swift          - Menu bar integration
├── Resources/
│   ├── en.lproj/
│   │   └── Localizable.strings       - Engelske oversættelser
│   └── da.lproj/
│       └── Localizable.strings       - Danske oversættelser
└── Info.plist
```

## Tekniske detaljer

### Crosshairs-tegning
- Akserne mødes ved musemarkøren med en justerbar centerradius
- Akserne strækker sig helt til skærmkanterne på alle monitorer
- Vinduet dækker alle skærme (union af alle screen.frame)
- 60 FPS opdatering for smooth cursor tracking

### Lokalisering
- NSLocalizedString bruges til alle brugervendte strenge
- Automatisk sprogvalg baseret på systemindstillinger
- Nem udvidelse med flere sprog

## Licens

Dette projekt er lavet som et alternativ til Microsoft PowerToys til macOS.
