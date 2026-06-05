# Release Notes - Version 1.3.1 & 1.3.1-alt

This document provides copy-paste-ready release notes for both versions of the **Cordova Exercises Health Plugin** released today.

---

## 🔵 Release Notes: `v1.3.1` (Branch: `main`)

### 📋 Overview
Version `1.3.1` is a minor release that updates and expands workout mapping coverage across both Android and iOS platforms to align with native OS additions and legacy backward compatibility.

### 🚀 Key Improvements
1. **iOS HealthKit Expansion**:
   * Added mapping support for **9 workout activity types** introduced in newer iOS versions (iOS 16+ / iOS 17+) to prevent them from falling through to the generic `"Other"` category.
   * Covered: `discSports`, `cooldown`, `fitnessGaming`, `cardioDance`, `socialDance`, `pickleball`, `underwaterDiving`, `swimBikeRun`, and `transition`.
2. **Android Health Connect Alignments**:
   * Added mapping support for **14 deprecated strength/calisthenics exercises** (e.g., `squat`, `plank`, `burpee`, `crunch`, `deadlift`) to ensure backward compatibility when parsing legacy user records in the Health Connect database.
   * Realigned activity `0` to map to `"other_workout"` instead of `"unknown"` to match the companion constant definition.

---

## 🟡 Release Notes: `v1.3.1-alt` (Branch: `alt-permissions`)

### 📋 Overview
Version `1.3.1-alt` contains the exact same workout/exercise mapping updates as `v1.3.1`, packaged on the `alt-permissions` branch.

### 🛡️ What makes the `alt` version different?
* **Omitted Heart Rate Permissions**: The `alt-permissions` version entirely omits queries and runtime permission requests for biometric heart rate data (`HeartRateRecord` on Android and `HKQuantityTypeIdentifierHeartRate` on iOS).
* **Target Apps**: Designed specifically for enterprise apps where heart rate data is not required, minimizing permission dialogs for the end user.
* **Step Count Integration (iOS)**: Requests step count permissions (`HKQuantityTypeIdentifierStepCount`) in place of heart rate.
