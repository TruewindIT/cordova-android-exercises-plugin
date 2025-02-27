# Cordova Android Exercises Plugin

This plugin provides access to exercise-related functionalities on Android devices.

## Installation

```bash
cordova plugin add cordova-android-exercises-plugin
```

## Usage

### Features

*   Requests exercise-related permissions on Android devices.
*   Retrieves workout data with associated TotalCalories, TActiveCalories and HeartRates

### Available Functions

*   `requestPermissions(successCallback, errorCallback)`: Requests the necessary permissions for accessing exercise data. This function requests the following permissions:
    *   `android.permission.READ_HEART_RATE`
    *   `android.permission.READ_STEPS`
    *   `android.permission.READ_EXERCISE`
    *   `android.permission.READ_EXERCISEROUTE`
    *   `android.permission.READ_DISTANCE`
    *   `android.permission.READ_ACTIVE_CALORIES_BURNED`
    *   `android.permission.READ_TOTAL_CALORIES_BURNED`

    It retrieves exercise data, such as steps, distance, and calories burned, and returns the response in JSON string format.
*   `getExerciseData(startTime, endTime, successCallback, errorCallback)`: Retrieves exercise data between the specified start and end times.

### Dependencies

The following dependencies are used in the `android/build.gradle` file:

*   `androidx.health.connect:connect-client:1.1.0-alpha07`: Provides the Health Connect API client for accessing health data.
*   `org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1`: Provides coroutines support for asynchronous programming in Kotlin.
*   `com.google.code.gson:gson:2.8.9`: A Java serialization/deserialization library to convert Java Objects into their JSON representation and vice versa.

### Example

```javascript
var startTime = "2025-02-26T10:30:00Z"
var endTime = "2025-02-27T10:30:00Z"
var RequestExercisePermissionsPlugin = cordova.plugins.RequestExercisePermissionsPlugin
RequestExercisePermissionsPlugin.requestPermissions(
    function(success){
        console.log("Permissions granted: " + success);
        // Call getExerciseData here, only if permissions were granted
        RequestExercisePermissionsPlugin.getExerciseData(
        startTime, endTime,
            function(success){
                console.log("Exercise data: " + success);
            },
            function(error){
                console.log("Exercise data error: " + error);
            }
        );
    },
    function(error){
        console.log("Permissions error: " + error);
    }
)
```

# Author
Developed by Henrique Silva at Axians DC Low-Code
henrique.silva@axians.com
