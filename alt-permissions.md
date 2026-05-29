# Branch Comparison: `main` vs. `alt-permissions`

This document explains the differences, architecture, and purpose of the **`alt-permissions`** branch compared to the **`main`** branch of the Cordova Exercises Health Plugin.

---

## 🎯 Purpose of `alt-permissions`

The `alt-permissions` branch was created for a specific enterprise client. It is designed to satisfy **strict privacy, security, and legal guidelines** regarding biometric data. 

While the `main` branch collects **Heart Rate (biometric)** data, the `alt-permissions` branch **completely excludes any requests, mappings, or databases queries for Heart Rate information** across both Android and iOS.

---

## 🔍 Detailed Differences

### 1. Requested Permissions

| Platform | `main` Branch | `alt-permissions` Branch | Purpose of Exclusion |
| :--- | :--- | :--- | :--- |
| **Android (Health Connect)** | Requests `READ_HEART_RATE` | **Omitted** | Prevents prompt for cardiovascular records |
| **iOS (HealthKit)** | Requests `HKQuantityTypeIdentifierHeartRate` | **Omitted** | Prevents prompt for heart rate biometric data |

*Android Manifest permissions and iOS Info.plist descriptions are automatically optimized on each branch to match only the declared permissions.*

---

### 2. Code Level Differences

#### **Android (Kotlin)**
*   **Permissions Set** ([src/android/RequestExercisePermissionsPlugin.kt](file:///Users/henriquefps/Documents/work-apps/cordova-android-exercises-plugin/src/android/RequestExercisePermissionsPlugin.kt#L307)):
    *   `main` requests: `HealthPermission.getReadPermission(HeartRateRecord::class)`.
    *   `alt-permissions` does **not** include the `HeartRateRecord` read permission.
*   **Build File Path** (`plugin.xml`):
    *   `main` targets `<framework src="android/build.gradle" .../>`
    *   `alt-permissions` targets `<framework src="src/android/build.gradle" .../>`

#### **iOS (Objective-C)**
*   **Authorization Set** ([src/ios/RequestExercisePermissionsPlugin.m](file:///Users/henriquefps/Documents/work-apps/cordova-android-exercises-plugin/src/ios/RequestExercisePermissionsPlugin.m#L27)):
    *   `main` initializes `readTypes` with `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate]`.
    *   `alt-permissions` completely omits `HKQuantityTypeIdentifierHeartRate`.
*   **Database Sub-Queries**:
    *   `main` executes an asynchronous `hrQuery` to fetch all heart rate values during the workout duration and maps them under `"additionalData": "HEART_RATE"`.
    *   `alt-permissions` bypasses the heart rate sub-query entirely, enhancing data loading performance and ensuring zero biometric traces reach the serialized JSON payload.

---

## 🚀 When to Use Which?

*   Use **`main`** for standard fitness, health monitoring, or wellness apps where full workout telemetry (including cardiovascular stress and heart rate zones) is desired.
*   Use **`alt-permissions`** for corporate wellness portals, insurance-linked apps, or enterprise environments where the collection of heart rate metrics is legally restricted or requires complex user consent agreements.
