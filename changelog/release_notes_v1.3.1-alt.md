# Release Notes - Version 1.3.1-alt

This document provides release notes for version **1.3.1-alt** of the **Cordova Exercises Health Plugin** released on the `alt-permissions` branch.

---

## 🟡 Release Notes: `v1.3.1-alt` (Branch: `alt-permissions`)

### 📋 Overview
Version `1.3.1-alt` is a minor release that updates and expands workout mapping coverage across both Android and iOS platforms to align with native OS additions and legacy backward compatibility. This version retains biometric **Heart Rate** data collection, but completely removes all `WRITE` permissions.

### 🛡️ What makes the `alt` version different?
* **Omitted WRITE Permissions**: This version entirely omits all `WRITE` permissions on Android (`WRITE_STEPS`, `WRITE_EXERCISE`, and `WRITE_EXERCISEROUTE`) to ensure the plugin operates strictly in a read-only capacity.
* **Target Apps**: Designed specifically for applications that only require reading health/exercise data, reducing the permission footprints required in app stores.

### 🚀 Key Improvements
1. **iOS HealthKit Expansion**:
   * Added mapping support for **9 workout activity types** introduced in newer iOS versions (iOS 16+ / iOS 17+) to prevent them from falling through to the generic `"Other"` category.
   * Covered: `discSports`, `cooldown`, `fitnessGaming`, `cardioDance`, `socialDance`, `pickleball`, `underwaterDiving`, `swimBikeRun`, and `transition`.
   * Restored full support for fetching **Heart Rate** samples (`HKQuantityTypeIdentifierHeartRate`).
2. **Android Health Connect Alignments**:
   * Added mapping support for **14 deprecated strength/calisthenics exercises** (e.g., `squat`, `plank`, `burpee`, `crunch`, `deadlift`) to ensure backward compatibility when parsing legacy user records in the Health Connect database.
   * Realigned activity `0` to map to `"other_workout"` instead of `"unknown"` to match the companion constant definition.
   * Restored full support for fetching **Heart Rate** records (`HeartRateRecord` / `READ_HEART_RATE`).
