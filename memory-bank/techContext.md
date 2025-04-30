# Technical Context: Cordova Android Exercises Plugin

**Core Technologies:**

*   **Cordova:** Hybrid application framework used to build the plugin structure and bridge JavaScript to native code.
    *   `cordova-android`: Specific platform targeted.
*   **Android Native Development:**
    *   **Language:** Kotlin (version inferred from `build.gradle` dependencies, likely 1.7.1+ based on coroutines version).
    *   **Build System:** Gradle.
*   **Android Health Connect SDK:** The primary API for accessing health and fitness data.
    *   Version: `androidx.health.connect:connect-client:1.1.0-alpha07` (specified in `android/build.gradle`).
    *   Key Components Used:
        *   `HealthConnectClient`: Main entry point for interacting with the SDK.
        *   `PermissionController`: Used for requesting permissions.
        *   `HealthPermission`: Defines specific read/write permissions for data types.
        *   Record Types: `ExerciseSessionRecord`, `DistanceRecord`, `TotalCaloriesBurnedRecord`, `ActiveCaloriesBurnedRecord`, `HeartRateRecord`.
        *   `ReadRecordsRequest`: Used to query data.
        *   `TimeRangeFilter`: Used to specify time boundaries for queries.
*   **Kotlin Coroutines:** Used for managing asynchronous operations when interacting with the Health Connect SDK.
    *   Version: `org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1` (specified in `android/build.gradle`).
*   **Gson:** Java library used for serializing Kotlin/Java objects into JSON format for returning data to the JavaScript layer.
    *   Version: `com.google.code.gson:gson:2.8.9` (specified in `android/build.gradle`).

**Development Setup & Build:**

*   Requires a standard Cordova development environment set up for Android.
*   Android SDK with appropriate `compileSdkVersion` (likely 33 or higher, based on Health Connect requirements, although `build.gradle` comments suggest 33, the active config might differ).
*   Gradle is used for building the Android native part.
*   The plugin relies on the host Cordova application's build process to compile the Kotlin code and integrate the plugin.
*   `plugin.xml` uses `<preference>` tags (`GradlePluginKotlinEnabled`, `AndroidXEnabled`) to influence the build process.

**Technical Constraints & Dependencies:**

*   **Health Connect Availability:** The plugin requires the Health Connect app to be installed on the target Android device. The `isHealthConnectAvailable()` function checks for SDK availability.
*   **Android Version:** Health Connect requires Android API level 28 (Android 9 Pie) or higher. The `minSdkVersion` in the commented-out section of `build.gradle` is 24, which might be too low if Health Connect is strictly required. The active configuration needs verification.
*   **Permissions:** The plugin requires specific Health Connect read permissions, which must be declared in `plugin.xml` (and thus `AndroidManifest.xml`) and granted by the user at runtime.
*   **Build Environment:** Potential build errors related to `compileSdkVersion`, Kotlin versions, AndroidX compatibility, or Gradle configuration might arise depending on the host Cordova project's setup. Past attempts indicated issues with `compileSdkVersion`.

**Tool Usage Patterns:**

*   `cordova.exec`: Standard Cordova mechanism for JS-to-native communication.
*   `HealthConnectClient`: Used for checking availability, requesting permissions (via `PermissionController`), and reading records.
*   Kotlin Coroutines (`runBlocking`, `async`, `launch`): Used extensively for asynchronous Health Connect operations.
*   Gson: Used for final data serialization before sending results back to JavaScript.
