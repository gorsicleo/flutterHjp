# Flutter HJP

A fast, offline-first **Croatian dictionary app** built with **Flutter**, using a locally stored **SQLite** database generated from the HJP (Hrvatski jezični portal) dataset.
Database is not provided since its contents are not public domain.

The app runs on **Android** and **Linux**, supports advanced linguistic data (inflections, phrases, etymology), and includes powerful developer features like a built-in SQL console.

---

## ✨ Features

### 📖 Dictionary

* Full Croatian dictionary stored locally (offline)
* Fast prefix & contains search
* Normalized search (handles accents and diacritics)
* Multiple meanings per word
* Internal cross-links between words

### 🧠 Linguistic Data

* **Izvedeni oblici** (inflections) rendered as structured tables
* **Frazeologija**, **Sintagma**, **Etimologija**, **Onomastika**
* HTML rendering for rich formatting
* Clickable references that open related entries

### ⭐ Personalization

* Save (favorite) words
* Search history
* “Word of the day”
* Random word discovery

### 🔍 Advanced Tools

* **System-wide text selection (Android)**
  Select any word → *Search in HJP*
* **Built-in SQL Console**

  * Run custom SQL queries against the dictionary
  * Optional *Danger mode* (allows all SQL commands)
  * Save & name SQL queries for later reuse

---

## 🛠️ Tech Stack

* **Flutter**
* **Dart**
* **SQLite**
* `sqflite` (mobile)
* `sqflite_common_ffi` (desktop)
* `flutter_html`
* `shared_preferences`

---

---

## 🗄️ Database

* Dictionary data should be stored in a **SQLite** database (`dictionary.sqlite`)
* On first launch, the database is copied from assets to local storage

> On desktop (Linux/macOS/Windows), SQLite is accessed via **FFI**.

---

## 🚀 Running the App

### Prerequisites

* Flutter (with Dart ≥ 3.10)
* Android SDK (for Android)
* Xcode (for iOS builds)
* Linux desktop enabled (for Linux)

### Run on Android

```bash
flutter run
```

### Run on Linux

```bash
flutter run -d linux
```

### Build release APK

```bash
flutter build apk --release
```

### Build iOS IPA

```bash
flutter build ipa --release
```

---

## ⚠️ SQL Console – Danger Mode

The SQL Console allows direct interaction with the dictionary database.

* **Safe mode**: SELECT queries only
* **Danger mode**: allows UPDATE / DELETE / DROP (use with care)

Saved SQL queries are stored locally and can be reused.

---

## 📌 Notes

* This project is intended for **educational, personal, and research use**
* Dictionary data originates from HJP and is stored locally
* No network access is required for dictionary usage

---

## 📄 License

This project is provided **as-is**.
Please ensure you have the right to use and distribute the dictionary data you include.
