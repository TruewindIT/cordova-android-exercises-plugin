# Project Overview

This is a Cordova plugin that provides access to exercise-related functionalities on both Android and iOS devices. It allows a Cordova-based application to request permissions and retrieve workout data, including metrics like distance, calories, and heart rate.

## Project Metadata

*   **Package Name:** `com.axians.requestexercisepermissionsplugin`
*   **Version:** `1.2.0`
*   **Author:** Axians
*   **License:** Apache 2.0 License
*   **Keywords:** `cordova`, `health`, `healthkit`, `health connect`, `permissions`, `android`, `ios`

## Building and Running

This is a Cordova plugin, so it's not a standalone application. It's meant to be added to a Cordova project.

To add this plugin to a Cordova project, run the following command in your Cordova project's root directory:

```bash
cordova plugin add <path-to-this-plugin>
```

### Dependencies

#### Android

The plugin uses the following Android dependencies:

*   `androidx.health.connect:connect-client:1.1.0-alpha07`: The Health Connect API client.
*   `org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1`: For asynchronous programming in Kotlin.
*   `com.google.code.gson:gson:2.8.9`: For JSON serialization/deserialization.

These dependencies are defined in `android/build.gradle`.

#### iOS

The plugin uses the `HealthKit.framework` on iOS.

### Dev Dependencies

*   `plist`: `^3.1.0`
*   `xcode`: `^3.0.1`

## Development Conventions

*   **Plugin Structure:** The plugin follows the standard Cordova plugin structure. The `plugin.xml` file defines the plugin's configuration, including the JavaScript interface, native source files, and permissions.
*   **JavaScript:** The JavaScript interface is defined in `www/RequestExercisePermissionsPlugin.js`. It uses `cordova/exec` to communicate with the native code.
*   **Android:** The Android implementation is written in Kotlin and is located in `src/android/`. It uses the Health Connect SDK to access exercise data.
*   **iOS:** The iOS implementation is written in Objective-C and is located in `src/ios/`. It uses the HealthKit framework to access exercise data.
*   **Permissions:** The plugin requests the necessary permissions for accessing exercise data on both Android and iOS. These permissions are declared in the `plugin.xml` file.
*   **Data Fetching:** The `getExerciseData` function retrieves exercise data between a specified start and end time. The data is returned as a JSON string.
