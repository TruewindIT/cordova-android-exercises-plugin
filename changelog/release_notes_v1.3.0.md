# Release Notes - Version 1.3.0 & 1.3.0-alt

This document provides copy-paste-ready release notes in English for both versions of the **Cordova Exercises Health Plugin** released today.

---

## 🔵 Release Notes: `v1.3.0` (Branch: `main`)

### 📋 Overview
Version `1.3.0` is a major release that transitions the Android implementation from alpha dependencies to the **official, stable production release of the Google Health Connect SDK**, resolves outstanding developer-facing build chain issues by modernizing the Kotlin compiler version, and dramatically expands iOS HealthKit workout activity type coverage.

> [!CAUTION]
> ### ⚠️ BREAKING CHANGE (Android `minSdkVersion` 26)
> To support the official stable Health Connect Client SDK (`1.1.0`), this plugin now strictly requires a minimum SDK version of **`26`** (Android 8.0 Oreo). 
> * **Impact**: If the host Cordova or Capacitor application defines a `minSdkVersion` lower than `26` (e.g., Capacitor's default `24`), the Android Gradle build will fail with a **Manifest Merger** exception.
> * **Resolution**: You must increase the host application's `minSdkVersion` to at least `26` (usually inside `variables.gradle` under `minSdkVersion = 26` for Capacitor, or via preference in `config.xml` for Cordova).
> * **Device Support**: The application will no longer run on devices older than Android 8.0.

---

### 🚀 What's New in this Version

#### **Android (Health Connect)**
*   **Stable SDK Upgrade**: Upgraded `androidx.health.connect:connect-client` from `1.1.0-alpha07` to **`1.1.0` (Stable / Production Ready)**, ensuring long-term API consistency and production support.
*   **Kotlin Compiler Modernization**: Updated the `GradlePluginKotlinVersion` preference in `plugin.xml` from `1.3.50` (released in 2019) to **`1.9.22`** (stable modern standard), eliminating build compatibility issues on modern Gradle and Android Studio environments.

#### **iOS (HealthKit)**
*   **New Workout Activity Mappings**: Added full native enum coverage in the `nameForWorkoutActivityType` mapping switch inside `RequestExercisePermissionsPlugin.m` to properly support and name newer physical activities introduced in recent iOS updates:
    *   `HKWorkoutActivityTypePickleball` $\rightarrow$ `"Pickleball"`
    *   `HKWorkoutActivityTypeSocialDance` $\rightarrow$ `"Social Dance"` *(modern successor to the deprecated `.dance` type)*
    *   `HKWorkoutActivityTypeCooldown` $\rightarrow$ `"Cooldown"`
    *   `HKWorkoutActivityTypeSwimBikeRun` $\rightarrow$ `"Swim Bike Run"` *(multisport / triathlons)*
    *   `HKWorkoutActivityTypeUnderwaterDiving` $\rightarrow$ `"Underwater Diving"`
    *   `HKWorkoutActivityTypeDiscSports` $\rightarrow$ `"Disc Sports"`
    *   `HKWorkoutActivityTypeFitnessGaming` $\rightarrow$ `"Fitness Gaming"`
    *   `HKWorkoutActivityTypeCardioDance` $\rightarrow$ `"Cardio Dance"`
*   Restored mapping coverage for `HKWorkoutActivityTypeMixedCardio` to ensure robust fallback handling.

#### **Documentation & Bug Fixes**
*   **JavaScript Month Bug Fix**: Corrected the JS Date constructor examples in `README.md` where `new Date(currentYear, 3, 1)` (representing April 1st) was incorrectly commented as `Jan 1st`. Updated it to `new Date(currentYear, 0, 1)`.
*   **Added Detailed JSON Schemas**: Fully documented the structured array response payload for both platforms to streamline client integrations.

---

### 📦 Installation
```bash
cordova plugin add https://github.com/TruewindIT/cordova-android-exercises-plugin.git#1.3.0
```

---
---

## 🟢 Release Notes: `v1.3.0-alt` (Branch: `alt-permissions`)

### 📋 Overview
Version `1.3.0-alt` is a customized release engineered specifically for corporate and enterprise clients with **strict biometric and privacy policies**. This branch **completely excludes any requests, permissions, or database queries for Heart Rate (biometric) data** on both platforms.

> [!CAUTION]
> ### ⚠️ BREAKING CHANGE (Android `minSdkVersion` 26)
> To support the official stable Health Connect Client SDK (`1.1.0`), this plugin now strictly requires a minimum SDK version of **`26`** (Android 8.0 Oreo). 
> * **Impact**: If the host application defines a `minSdkVersion` lower than `26`, the Android Gradle build will fail with a **Manifest Merger** exception.
> * **Resolution**: You must increase the host application's `minSdkVersion` to at least `26`.

---

### 🚀 What's New in this Version

#### **Biometrics & Privacy Enforcement (Branch Specific)**
*   **Biometric Data Exclusion**: Completely omitted permission requests for `READ_HEART_RATE` on Android and `HKQuantityTypeIdentifierHeartRate` on iOS.
*   **Zero Biometric Trace**: Native sub-queries completely bypass cardiovascular data collection. The serialized JSON payload is architecturally guaranteed to be free of heart rate measurements.

#### **Replicated Android & iOS Upgrades**
*   **Stable SDK Upgrade**: Upgraded `androidx.health.connect:connect-client` dependency from `1.1.0-alpha07` to **`1.1.0` (Stable)** in `src/android/build.gradle`.
*   **Kotlin Compiler Modernization**: Updated `GradlePluginKotlinVersion` to **`1.9.22`** in `plugin.xml`.
*   **New Workout Activity Mappings (iOS)**: Replicated the comprehensive HealthKit activity type mappings (`Pickleball`, `Social Dance`, `Cooldown`, `Swim Bike Run`, `Underwater Diving`, etc.) inside `RequestExercisePermissionsPlugin.m`.

---

### 📦 Installation
```bash
cordova plugin add https://github.com/TruewindIT/cordova-android-exercises-plugin.git#1.3.0-alt
```
