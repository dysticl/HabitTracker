iOS Habit Tracker
Ein iOS-basierter Habit Tracker, entwickelt in Swift mit SwiftUI, der Nutzern hilft, Gewohnheiten zu verfolgen, Fortschritte zu messen und Deadlines zu setzen. Die App kommuniziert mit einem Node.js-Backend und einer MySQL-Datenbank, um Habits zu speichern und Beweise (z. B. Fotos) hochzuladen.
 
Funktionen

Habit-Verwaltung: Erstelle, bearbeite, lösche und markiere Gewohnheiten als abgeschlossen.
Deadline-Feature: Setze Deadlines in Stunden (z. B. 2h für „100 Push-ups“), mit einem dynamischen Countdown-Timer, der das neueste aktive Habit anzeigt.
Beweis-Upload: Lade Fotos hoch, um den Abschluss eines Habits zu bestätigen.
Wiederkehrende Habits: Unterstützung für wiederkehrende Gewohnheiten, die nach Abschluss zurückgesetzt werden.
Fortschrittsverfolgung: Visualisiere Fortschritt mit Fortschrittsbalken und XP-Punkten.
Streak-System: Verfolge deinen Streak mit einer visuellen Flammenanzeige.
Modernes UI: Elegantes, dunkles Design mit Blur-Effekten, entwickelt in SwiftUI.
API-Integration: Kommunikation mit einem Node.js-Backend über REST-API.

Technologien
Frontend (iOS)

Swift 5: Programmiersprache für die iOS-App.
SwiftUI: Framework für die Benutzeroberfläche.
Xcode: Entwicklungsumgebung.
PhotosUI: Für den Foto-Upload.
Charts: Für XP-Diagramme.

Backend

Node.js: Server mit Express.js.
MySQL: Datenbank für Habits.
express-fileupload: Für den Upload von Beweisfotos.
PM2: Prozessmanager für den Server.

Voraussetzungen

iOS: Xcode 15 oder höher, iOS 16 oder höher.
Backend: Node.js 16+, MySQL 8+, PM2.
API-Schlüssel: Ein gültiger API-Schlüssel für die Backend-Kommunikation.

Installation
1. iOS-App

Repository klonen:git clone [(https://github.com/dysticl/HabitTracker.git)](https://github.com/dysticl/HabitTracker.git)
cd habit-tracker


Xcode-Projekt öffnen:Öffne HabitTracker.xcodeproj in Xcode.
API-Schlüssel konfigurieren:
Öffne APIManager.swift.
Ersetze your-secret-api-key-1234567890 mit deinem API-Schlüssel:private let apiKey = "dein-api-schlüssel"




App bauen und ausführen:
Wähle ein iOS-Gerät oder Simulator in Xcode.
Drücke ⌘+B zum Bauen und ⌘+R zum Ausführen.



2. Backend-Server

Backend-Verzeichnis:Navigiere in das Backend-Verzeichnis (z. B. server).
Abhängigkeiten installieren:npm install


# Habit Tracker Setup Guide

## MySQL-Datenbank einrichten

### Erstelle eine Datenbank namens `habit_tracker_db`:
```sql
CREATE DATABASE habit_tracker_db;
```

### Erstelle die `habits`-Tabelle:
```sql
CREATE TABLE habits (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    emoji VARCHAR(10) DEFAULT '⭐️',
    xp_points INT DEFAULT 10,
    is_completed BOOLEAN DEFAULT FALSE,
    progress DOUBLE DEFAULT 0.0,
    is_recurring BOOLEAN DEFAULT FALSE,
    deadline_duration INT DEFAULT NULL
);
```

## Datenbankverbindung konfigurieren

Öffne `index.js` und passe die MySQL-Verbindung an:
```js
const pool = mysql.createPool({
    host: 'localhost',
    user: 'dein-benutzername',
    password: 'dein-passwort',
    database: 'habit_tracker_db'
});
```

### Ersetze den API-Schlüssel:
```js
const API_KEY = 'dein-api-schlüssel';
```

## Uploads-Ordner erstellen
```bash
mkdir Uploads
```

## Server starten
```bash
pm2 start index.js --name habit-tracker-api
pm2 logs habit-tracker-api
```
Der Server läuft auf [http://localhost:3000](http://localhost:3000).

---

## Nutzung

### App starten
- Öffne die App auf deinem iOS-Gerät oder Simulator.
- Die App lädt automatisch vorhandene Habits vom Server.

### Habit erstellen
- Klicke auf „Add Habit“.
- Gib einen Namen (z. B. „100 Push-ups“) und optional eine Deadline in Stunden (z. B. „2“) ein.
- Das Emoji wird automatisch auf „⭐️“ gesetzt.
- Klicke auf das Häkchen, um das Habit zu erstellen.

### Countdown-Timer
- Der Timer zeigt die Deadline des neuesten aktiven Habits an (z. B. „02:00:00“ für 2 Stunden).
- Wenn die Zeit abläuft, wechselt der Timer zum nächsten aktiven Habit oder setzt auf 1 Stunde zurück.

### Beweis hochladen
- Tippe auf das Kreissymbol eines Habits.
- Wähle ein Foto aus und lade es hoch.
- Nicht-wiederkehrende Habits werden nach dem Upload gelöscht; wiederkehrende werden zurückgesetzt.

### Habits verwalten
- Toggle „repeat“ für wiederkehrende Habits.
- Sieh Fortschritt und XP-Punkte in der UI.

---

## API-Endpunkte

Das Backend bietet folgende REST-Endpunkte (alle erfordern `X-API-Key` im Header):

### POST /habits
Erstellt ein neues Habit.
```json
Body: {
  "name": "string",
  "emoji": "string",
  "xp_points": number,
  "is_completed": boolean,
  "progress": number,
  "is_recurring": boolean,
  "deadline_duration": number|null
}
```
Antwort: 201 mit Habit-Objekt.

### GET /habits
Listet alle Habits, sortiert nach ID (neueste zuerst).  
Antwort: 200 mit Array von Habit-Objekten.

### POST /habits/:id/proof
Lädt einen Beweis (Foto) hoch.
```json
Body: Multipart-Form mit `proof` (JPEG)
```
Antwort: 204 (nicht-wiederkehrend, gelöscht) oder 200 (wiederkehrend, aktualisiert).

### PUT /habits/:id
Aktualisiert ein Habit.
```json
Body: wie bei POST /habits
```
Antwort: 200 mit aktualisiertem Habit.

### DELETE /habits/:id
Löscht ein Habit.  
Antwort: 204 bei Erfolg.

---

## Datenbankstruktur

Die `habits`-Tabelle hat folgende Spalten:

| Spalte            | Typ          | Beschreibung                         |
|-------------------|--------------|--------------------------------------|
| id                | INT          | Primärschlüssel, Auto-Increment      |
| name              | VARCHAR(255) | Name des Habits                      |
| emoji             | VARCHAR(10)  | Emoji (Standard: „⭐️“)               |
| xp_points         | INT          | XP-Punkte (Standard: 10)             |
| is_completed      | BOOLEAN      | Abgeschlossen (Standard: false)      |
| progress          | DOUBLE       | Fortschritt (0.0–1.0)                |
| is_recurring      | BOOLEAN      | Wiederkehrend (Standard: false)      |
| deadline_duration | INT          | Deadline in Sekunden (optional)      |

---

## Projektstruktur

```plaintext
habit-tracker/
├── HabitTracker.xcodeproj/     # Xcode-Projekt
├── HabitTracker/               # iOS-App
│   ├── ContentView.swift       # Haupt-UI mit Timer und Habit-Liste
│   ├── HabitViewModel.swift    # Logik für Habits und API-Aufrufe
│   ├── APIManager.swift        # API-Kommunikation
├── server/                     # Backend
│   ├── index.js                # Node.js-Server
│   ├── Uploads/                # Ordner für Beweisfotos
│   ├── package.json            # Node.js-Abhängigkeiten
├── README.md                   # Diese Datei
```
"""
Bekannte Probleme

Der API-Schlüssel ist hartcodiert; für Produktion in Umgebungsvariablen auslagern.
Keine Offline-Unterstützung; die App benötigt eine Internetverbindung.
Beweisfotos werden nur als JPEG unterstützt.

Beitragen

Fork das Repository.
Erstelle einen Feature-Branch:git checkout -b feature/deine-funktion


Commit deine Änderungen:git commit -m "Feature: Beschreibung"


Push und erstelle einen Pull Request:git push origin feature/deine-funktion



Lizenz:
MIT-Lizenz. Siehe LICENSE für Details.

Kontakt:
Für Fragen oder Feedback, öffne ein Issue oder kontaktiere: daniel@davysgray.com
