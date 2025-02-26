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
// Request permissions
RequestExercisePermissionsPlugin.requestPermissions();

cordova.plugins.RequestExercisePermissionsPlugin.getExerciseData(
  "2025-02-01T10:30:00Z", "2025-03-01T10:30:00Z",
        function(success) {
          // Success callback
          console.log("Success: "+success);
          console.log(typeof(success))
        },
        function(error) {
          // Error callback
          console.error("Error: "+error);
        }
      );

# Author
Developed by Henrique Silva at Axians DC Low-Code