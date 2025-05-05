# Cordova Health Exercises Plugin

This plugin provides access to exercise-related functionalities on both Android and iOS devices.

## Installation

```bash
cordova plugin add cordova-android-exercises-plugin
```

## Usage

### Features

*   Requests exercise-related permissions on Android and iOS devices.
*   Retrieves workout data with associated metrics like distance, calories, and heart rate.

### Available Functions

*   `requestPermissions(successCallback, errorCallback)`: Requests the necessary permissions for accessing exercise data.
    *   **Android Permissions:**
        *   `android.permission.READ_HEART_RATE`
        *   `android.permission.READ_STEPS`
        *   `android.permission.READ_EXERCISE`
        *   `android.permission.READ_EXERCISEROUTE`
        *   `android.permission.READ_DISTANCE`
        *   `android.permission.READ_ACTIVE_CALORIES_BURNED`
        *   `android.permission.READ_TOTAL_CALORIES_BURNED`
    *   **iOS Permissions:** The plugin requests access to various HealthKit data types, including:
        *   Workouts
        *   Active Energy Burned
        *   Basal Energy Burned
        *   Heart Rate
        *   Distance Walking/Running
        *   Distance Cycling
        *   Distance Swimming
        *   Distance Wheelchair
        *   Step Count

*   `getExerciseData(startTime, endTime, successCallback, errorCallback)`: Retrieves exercise data between the specified start and end times.

### Dependencies

#### Android

The following dependencies are used in the `android/build.gradle` file:

*   `androidx.health.connect:connect-client:1.1.0-alpha07`: Provides the Health Connect API client for accessing health data.
*   `org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1`: Provides coroutines support for asynchronous programming in Kotlin.
*   `com.google.code.gson:gson:2.8.9`: A Java serialization/deserialization library to convert Java Objects into their JSON representation and vice versa.

#### iOS

The plugin relies on the following iOS frameworks and dependencies:

*   `HealthKit.framework`: Provides access to the HealthKit framework for accessing health data.
*   `cordova-plugin-add-swift-support`: Adds Swift support to the Cordova project.

### Example

```javascript
const healthPlugin = cordova.plugins.RequestExercisePermissionsPlugin;

if (!healthPlugin) {
    console.error('Health Plugin not found!');
    return;
}

// 1. Request Permissions
healthPlugin.requestPermissions(
    function(successMsg) {
        console.log('Permission request success:', successMsg);

        // 2. Get Exercise Data for January of the current year
        const currentYear = new Date().getFullYear();
        // Note: JavaScript months are 0-indexed (0 = January)
        const startDate = new Date(currentYear, 3, 1, 0, 0, 0, 0); // Jan 1st, 00:00:00
        const endDate = new Date(currentYear, 4, 1, 0, 0, 0, 0);   // Feb 1st, 00:00:00 (Query is exclusive of end date)

        // Format dates as ISO 8601 strings
        const startDateISO = startDate.toISOString();
        const endDateISO = endDate.toISOString();

        console.log(`Fetching data from ${startDateISO} to ${endDateISO} (Month of January ${currentYear})`);

        healthPlugin.getExerciseData(
            startDateISO,
            endDateISO,
            function(jsonData) {
                console.log('Exercise data received (JSON string):', jsonData);
                try {
                    const data = JSON.parse(jsonData);
                    console.log('Parsed exercise data:', data);
                    // Display data in the app's UI if desired
                } catch (e) {
                    console.error('Error parsing JSON data:', e);
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

### Known Issues

*   **iOS Authorization Status:** In some cases, the `authorizationStatus(for:)` method may return `.sharingDenied` even after the user has granted permissions in the Settings app. This issue may be related to the provisioning profile or HealthKit entitlements.
*   **Potential iOS Risks:** The current Swift code omits `[weak self]` in closures, which may cause retain cycles. Additionally, the removal of explicit thread safety may cause race conditions during result aggregation.

# Author
Developed by Henrique Silva at Axians DC Low-Code
henrique.silva@axians.com
