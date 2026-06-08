# Cordova Health Exercises Plugin (Alternative Permissions Branch)

This branch of the Cordova Exercises Health Plugin provides a customized, unified API designed for clients who do **not** require write permissions or route/GPS tracking. It requests specific read permissions and retrieves workout data with associated metrics like distance, step count, heart rate, and calories from **Android Health Connect** and **iOS HealthKit**.

---

## Installation

You can install the plugin via Cordova CLI:

```bash
cordova plugin add com.axians.requestexercisepermissionsplugin
```

Or reference it directly via a Git URL or local folder:

```bash
cordova plugin add https://github.com/TruewindIT/cordova-android-exercises-plugin.git#alt-permissions
```

---

## Technical Features

*   **Customized Permission Set**: Omit write access and route/GPS tracking to satisfy strict enterprise privacy and compliance guidelines.
*   **Unified API**: Standardized access to Health Connect (Android) and HealthKit (iOS).
*   **Permissions Management**: Fully supports modern OS permissions, including Android 14+ Health Connect permissions rationale and iOS HealthKit authorization.
*   **Granular Metrics**: Fetches workouts and matches them with precise metrics, including:
    *   Active & Basal Energy Burned (Calories)
    *   Step Count
    *   Heart Rate (BPM)
    *   Activity-specific distance types (Running/Walking/Cycling/Swimming/Wheelchair, and iOS 18+ specific types like Rowing/Paddle/Skating/Skiing)
*   **Robust Architecture**: 
    *   **Android**: Built using Kotlin, Coroutines for non-blocking I/O, and official Health Connect client (`1.1.0`).
    *   **iOS**: Written in Objective-C using GCD (`dispatch_group_t` & a serial queue to ensure thread-safe collection of samples) and `__weak` references to prevent retain cycles.

---

## API Reference

The plugin is exposed via `cordova.plugins.RequestExercisePermissionsPlugin`.

### `requestPermissions(successCallback, errorCallback)`

Requests the necessary permissions to access health and workout data.

#### Requested Permissions (No Write / No Route)

| Platform | Permission / Identifier | Description |
| :--- | :--- | :--- |
| **Android** | `READ_STEPS` | Read step counts |
| | `READ_EXERCISE` | Read exercise sessions |
| | `READ_HEART_RATE` | Read heart rate records |
| | `READ_DISTANCE` | Read distance records |
| | `READ_ACTIVE_CALORIES_BURNED` | Read active energy |
| | `READ_TOTAL_CALORIES_BURNED` | Read total energy |
| **iOS** | `HKWorkoutType` | Read workout history |
| | `HKQuantityTypeIdentifierActiveEnergyBurned` | Read active energy burned |
| | `HKQuantityTypeIdentifierBasalEnergyBurned` | Read basal energy burned |
| | `HKQuantityTypeIdentifierHeartRate` | Read heart rate metrics |
| | `HKQuantityTypeIdentifierDistance*` | Read distance (Walking/Running, Cycling, Swimming, etc.) |
| | `HKQuantityTypeIdentifierStepCount` | Read step count |

---

### `getExerciseData(startTime, endTime, successCallback, errorCallback)`

Retrieves exercise data between the specified start and end times. Both times should be provided as ISO 8601 formatted strings (e.g., `YYYY-MM-DDTHH:mm:ss.sssZ`).

#### JSON Output Format

The `successCallback` receives a serialized JSON string representing an array of exercise objects. 

```json
[
  {
    "startDate": "2026-05-20T08:00:00.000Z",
    "endDate": "2026-05-20T09:00:00.000Z",
    "duration": 3600,
    "activity": "running",
    "totalDistance": 10450.2,
    "totalEnergyBurned": 680.5,
    "samples": [
      {
        "startDate": "2026-05-20T08:00:00.000Z",
        "endDate": "2026-05-20T09:00:00.000Z",
        "block": 1,
        "values": [620.0],
        "additionalData": "ACTIVE_CALORIES_BURNED"
      }
    ]
  }
]
```

---

## Configuration & Platform Specifics

### Android (Health Connect)

1. **Android 14+ Rationale**:
   Beginning in Android 14, apps must declare an Activity to explain Health Connect data usage (Privacy Policy link / permissions rationale). The plugin automatically declares `HealthActivityPermissions` with an intent filter to handle the `ACTION_SHOW_PERMISSIONS_RATIONALE` and `VIEW_PERMISSION_USAGE` actions.
2. **Permissions declaration**:
   The required `<uses-permission>` tags are automatically injected into your `AndroidManifest.xml` via the plugin configuration.

### iOS (HealthKit)

1. **Info.plist Keys**:
   The plugin automatically appends the required privacy declarations to your project's `*-Info.plist`:
   *   `NSHealthShareUsageDescription`: Explains why the app reads health data.
   *   `NSHealthUpdateUsageDescription`: Explains why the app updates health data.
2. **Entitlements**:
   The HealthKit entitlement is automatically added to both `Entitlements-Debug.plist` and `Entitlements-Release.plist` during build time.

---

## Code Example

```javascript
const healthPlugin = cordova.plugins.RequestExercisePermissionsPlugin;

if (!healthPlugin) {
    console.error('Health Plugin not found!');
    return;
}

// 1. Request Permissions
healthPlugin.requestPermissions(
    function(successMsg) {
        console.log('Permission request process completed:', successMsg);

        // 2. Query data for the month of January of the current year
        const currentYear = new Date().getFullYear();
        
        // JavaScript months are 0-indexed (0 = January)
        const startDate = new Date(currentYear, 0, 1, 0, 0, 0, 0); // Jan 1st, 00:00:00
        const endDate = new Date(currentYear, 1, 1, 0, 0, 0, 0);   // Feb 1st, 00:00:00 (Exclusive)

        // Convert to ISO 8601 strings
        const startDateISO = startDate.toISOString();
        const endDateISO = endDate.toISOString();

        console.log(`Fetching data from ${startDateISO} to ${endDateISO} (January ${currentYear})`);

        healthPlugin.getExerciseData(
            startDateISO,
            endDateISO,
            function(jsonData) {
                try {
                    const exercises = JSON.parse(jsonData);
                    console.log(`Successfully fetched ${exercises.length} exercise records:`, exercises);
                } catch (e) {
                    console.error('Error parsing exercise JSON:', e);
                }
            },
            function(errorMsg) {
                console.error('Error getting exercise data:', errorMsg);
            }
        );
    },
    function(errorMsg) {
        console.error('Permission request error:', errorMsg);
    }
);
```

---

## Known Behaviors & Troubleshooting

*   **iOS Privacy Constraints**:
    If a user denies permission to read specific types (e.g. Distance) in the iOS Health Settings, iOS will return an empty list of samples instead of throwing an error. This is a deliberate privacy feature of Apple's HealthKit to prevent fingerprinting.
*   **Android Health Connect App**:
    On Android devices running Android 13 or lower, the user must have the **Health Connect** application installed from the Google Play Store for the API to function. On Android 14+, Health Connect is integrated directly into the OS Settings.

---

## Author
Developed by **Henrique Silva** at Axians DC Low-Code (henrique.silva@axians.com).
