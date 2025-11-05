# Installation og Byg Guide

## Trin 1: Installer Xcode

### Fra App Store (Anbefalet)
1. Åbn **App Store** på din Mac
2. Søg efter "**Xcode**"
3. Klik på **Hent** knappen (gratis, men ca. 15 GB)
4. Vent på download (30-60 minutter afhængigt af din internetforbindelse)
5. Installer når den er downloaded

### Første gang setup
Efter installationen, åbn Terminal og kør:

```bash
# Accepter Xcode licens
sudo xcodebuild -license accept

# Bekræft Xcode developer tools er installeret
xcode-select --install
```

## Trin 2: Åbn Projektet

1. Naviger til projektmappen i Terminal:
```bash
cd /Users/rp/Documents/Projekter/macredcross
```

2. Åbn projektet i Xcode:
```bash
open MouseCrosshairs.xcodeproj
```

ELLER dobbeltklik på `MouseCrosshairs.xcodeproj` i Finder.

## Trin 3: Byg og Kør Appen

### I Xcode:
1. Vælg **Product → Run** fra menuen (eller tryk **⌘R**)
2. Xcode vil bygge projektet
3. Appen starter automatisk

### Ved første kørsel vil du se:
1. **Onboarding guide** på dansk/engelsk (afhængigt af dit systemsprog)
2. Fire informative sider der forklarer funktionerne
3. **Vigtig**: Du bliver bedt om at give **Accessibility tilladelse**
   - Dette er nødvendigt for globale tastaturgenveje
   - Klik på "Åbn systemindstillinger" knappen
   - I Systemindstillinger: **Privatliv og sikkerhed → Tilgængelighed**
   - Aktiver **MouseCrosshairs**

## Trin 4: Brug Appen

### Menu Bar:
- Find trådkors-ikonet i din menu bar (øverst til højre)
- Klik for at se menu med:
  - **Toggle Crosshairs**: Slå trådkors til/fra
  - **Settings**: Åbn indstillinger
  - **About**: Information om appen
  - **Quit**: Luk appen

### Tastaturgenvej:
- Tryk **⌘⇧C** (Command + Shift + C) når som helst for at slå trådkors til/fra

### Indstillinger:
- Tilpas farver, tykkelse, gennemsigtighed
- Vælg orientering (vandret/lodret/begge)
- Sæt fast længde eller brug fuld skærm
- Juster center radius omkring musemarkøren

## Problemløsning

### "Developer cannot be verified" fejl:
Hvis macOS blokerer appen første gang:
1. Gå til **Systemindstillinger → Privatliv og sikkerhed**
2. Rul ned til "Sikkerhed" sektionen
3. Klik **Åbn alligevel** ved siden af advarslen om MouseCrosshairs

### Xcode bygge-fejl:
Hvis du får fejl under bygning:
1. Ryd build cache: **Product → Clean Build Folder** (⇧⌘K)
2. Prøv at bygge igen

### Tastaturgenveje virker ikke:
- Tjek at Accessibility tilladelse er givet
- Genstart appen efter at have givet tilladelsen

### Crosshairs vises ikke på alle skærme:
- Appen understøtter multi-monitor automatisk
- Hvis problemer: Prøv at slå crosshairs fra og til igen

## Test Funktioner

### Basic test:
1. Tryk **⌘⇧C** for at aktivere crosshairs
2. Bevæg musen - akserne følger markøren
3. Akserne skal strække sig til alle skærmkanter
4. Tryk **⌘⇧C** igen for at deaktivere

### Multi-monitor test (hvis du har flere skærme):
1. Aktiver crosshairs
2. Bevæg musen mellem skærme
3. Akserne skal følge på tværs af alle skærme

### Indstillinger test:
1. Åbn indstillinger fra menu bar
2. Ændre farve - crosshairs opdateres i real-time
3. Juster tykkelse og gennemsigtighed
4. Test forskellige orienteringer

### Sprogtest:
1. Skift dit systems sprog til engelsk/dansk
2. Genstart appen
3. Alle tekster skal være på det nye sprog

## Næste Skridt

Efter appen kører:
- Tilpas indstillingerne efter dine behov
- Test på forskellige skærme hvis du har det
- Prøv forskellige farver og tykkelser
- Aktiver "Fast længde" hvis du ikke vil have fuld skærm

## Support

Hvis du oplever problemer:
1. Tjek denne guide igen
2. Se README.md for tekniske detaljer
3. Tjek at alle systemkrav er opfyldt

God fornøjelse med Mouse Crosshairs! 🎯
