# Product Context: Cordova Health Exercises Plugin (Android & iOS)

**Problem:** Cordova applications lack a standardized way to access detailed exercise data stored in native health platforms like Android's Health Connect and Apple's HealthKit. Developers need a reliable plugin to bridge this gap for cross-platform apps.

**Solution:** This plugin provides a simple, unified JavaScript interface for Cordova apps to request permissions and retrieve exercise session/workout data from both Health Connect (Android) and HealthKit (iOS).

**How it Works:**

1.  The Cordova app calls the plugin's unified JavaScript functions (`requestPermissions` or `getExerciseData`).
2.  `cordova.exec` routes the call to the appropriate native implementation based on the platform.
3.  **On Android:**
    *   The plugin's native Kotlin code (`RequestExercisePermissionsPlugin.kt`) interacts with the Health Connect SDK.
    *   If permissions are needed, a dedicated Android Activity (`HealthActivityPermissions`) handles the request flow.
    *   For data retrieval, the plugin queries Health Connect for `ExerciseSessionRecord` and related data types within a specified time range.
4.  **On iOS:**
    *   The plugin's native Swift code (`RequestExercisePermissionsPlugin.swift`) interacts with the HealthKit framework.
    *   If permissions are needed, `HKHealthStore.requestAuthorization` presents the standard iOS HealthKit permission sheet.
    *   For data retrieval, the plugin uses `HKSampleQuery` to fetch `HKWorkout` objects within a specified time range.
5.  The fetched data (from either platform) is aggregated and formatted into a consistent JSON string structure.
6.  The JSON data is returned to the Cordova app via the JavaScript callback.

**User Experience Goals:**

*   **Seamless Permissions:** The permission request process should be clear and follow platform best practices (Health Connect UI on Android, HealthKit UI on iOS).
*   **Reliable Data Access:** The plugin should consistently fetch accurate exercise data available on each platform.
*   **Developer Friendly:** The unified JavaScript API should be simple and easy to integrate into Cordova projects targeting both Android and iOS.
