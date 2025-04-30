# Product Context: Cordova Android Exercises Plugin

**Problem:** Cordova applications lack a standardized way to access detailed exercise data stored in Android's Health Connect platform. Developers need a reliable plugin to bridge this gap.

**Solution:** This plugin provides a simple interface for Cordova apps to request permissions and retrieve exercise session data from Health Connect.

**How it Works:**

1.  The Cordova app calls the plugin's JavaScript functions (`requestPermissions` or `getExerciseData`).
2.  The plugin's native Kotlin code interacts with the Health Connect SDK.
3.  If permissions are needed, the plugin launches a dedicated Android Activity (`HealthActivityPermissions`) to handle the permission request flow.
4.  For data retrieval, the plugin queries Health Connect for `ExerciseSessionRecord` and related data types (Distance, Calories, Heart Rate) within a specified time range.
5.  The fetched data is aggregated and formatted into a JSON string.
6.  The JSON data is returned to the Cordova app via the JavaScript callback.

**User Experience Goals:**

*   **Seamless Permissions:** The permission request process should be clear and follow Android best practices.
*   **Reliable Data Access:** The plugin should consistently fetch accurate exercise data.
*   **Developer Friendly:** The JavaScript API should be simple and easy to integrate into Cordova projects.
