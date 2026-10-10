# HealthFam

Native iPhone- und Apple-Watch-App im Stil von **Bevel**: Recovery, Strain, Schlaf, Stress und Energie, berechnet aus deinen Apple-Health-Daten und verglichen mit deinen eigenen Normalwerten.

## Funktionen

| Bereich | Was die App macht |
|---|---|
| **Recovery** (0–100 %) | Nächtliche HRV, Ruhepuls, Atemfrequenz, Handgelenkstemperatur und Schlaf-Score, jeweils als z-Wert gegen deine persönliche 30-Tage-Baseline |
| **Strain** (0–100 %) | Trainingsimpuls (TRIMP nach Banister) aus allen Herzfrequenzmessungen des Tages, dazu Herzfrequenzzonen und ein **Tagesziel**, das sich nach der Recovery richtet |
| **Schlaf** (0–100 %) | Dauer im Verhältnis zum Schlafbedarf (Ziel + Zuschlag für die Belastung vom Vortag), Effizienz, Tief- und REM-Anteil, Regelmäßigkeit, Hypnogramm |
| **Stress** | Stündlicher Stressverlauf aus dem Ruhepuls außerhalb von Training und Schlaf, inkl. geführter Atemübung (wird als Achtsamkeitsminuten gespeichert) |
| **Energie** | Wie viel „Akku“ dir nach Recovery, Strain und Stress heute noch bleibt |
| **Coach** | Verständliche Hinweise, z. B. zu Schlafdefizit, HRV-Trend, erhöhter Temperatur oder Überlastung |
| **Trends** | Verläufe über 7, 30 oder 60 Tage für alle Kennzahlen, mit Vergleich zur Vorperiode |
| **Training** | Trainingsliste mit Strain pro Einheit sowie akute vs. chronische Trainingslast |
| **Ernährung** | Kalorien, Makros und Wasser aus Apple Health; Mahlzeiten und Wasser lassen sich direkt erfassen |
| **Journal** | Gewohnheiten erfassen (Alkohol, Koffein, Sauna …) und sehen, wie sie die Recovery am nächsten Tag beeinflussen |
| **Apple Watch** | Ringe und Vitalwerte am Handgelenk, Live-Training mit Echtzeit-Strain und Herzfrequenzzone; das Training wird in Apple Health gespeichert |

Alle Daten werden ausschließlich auf dem Gerät verarbeitet.

## Projektstruktur

```
Packages/HealthFamCore/   Plattformunabhängige Logik (Modelle, Scores, Baseline, Journal-Analyse, Demo-Daten) + Unit-Tests
App/Shared/               HealthKit-Anbindung und Design (iPhone + Watch)
App/iOS/                  iPhone-App (SwiftUI, Swift Charts)
App/Watch/                watchOS-App (SwiftUI, HKWorkoutSession)
project.yml               XcodeGen-Projektdefinition
```

## Auf dem iPhone installieren

Voraussetzungen: ein Mac mit **Xcode 16** oder neuer, ein iPhone mit iOS 17+ und optional eine Apple Watch mit watchOS 10+.

1. Abhängigkeit installieren und das Xcode-Projekt erzeugen:
   ```bash
   brew install xcodegen
   xcodegen generate
   open HealthFam.xcodeproj
   ```
2. In Xcode bei beiden Targets (`HealthFam` und `HealthFamWatch`) unter **Signing & Capabilities** dein Team auswählen. Eine kostenlose Apple-ID reicht für dein eigenes Gerät. Ist die Bundle-ID schon vergeben, ändere `com.healthfam` in `project.yml` und erzeuge das Projekt neu.
3. iPhone per Kabel verbinden, als Ziel auswählen und auf **Run** klicken. Die Watch-App wird automatisch mitinstalliert. Falls nicht: in der Watch-App auf dem iPhone unter „Verfügbare Apps“ installieren.
4. Beim ersten Start **„Mit Apple Health verbinden“** tippen und alle Kategorien freigeben.

Ohne Apple Watch oder im Simulator kannst du mit **„Erst mit Demo-Daten ausprobieren“** starten. Umschalten lässt sich das jederzeit in den Einstellungen.

> Tipp: Damit Recovery und Schlaf funktionieren, die Apple Watch nachts tragen und in der Health-App den Schlaffokus bzw. die Schlaferfassung aktivieren. Nach ungefähr einer Woche ist die persönliche Baseline kalibriert.

Für TestFlight oder den App Store brauchst du ein kostenpflichtiges Apple-Developer-Konto. Danach in Xcode **Product › Archive** wählen und hochladen.

## Tests

```bash
cd Packages/HealthFamCore
swift test
```

GitHub Actions (`.github/workflows/ci.yml`) führt bei jedem Push die Tests aus und baut die iPhone- und die Watch-App.

## Hinweis

HealthFam ist keine Medizinprodukt-Software und ersetzt keine ärztliche Beratung.
