# Project Brief: Cordova Health Exercises Plugin (Android & iOS)

**Goal:** Create a Cordova plugin for Android and iOS to extract exercise session data from the native health platforms (Android Health Connect SDK and Apple HealthKit).

**Core Requirements:**

*   Integrate with the Health Connect SDK on Android.
*   Integrate with the HealthKit framework on iOS.
*   Provide a unified JavaScript interface (`requestPermissions`, `getExerciseData`) for Cordova applications to interact with the plugin on both platforms.
*   Request necessary permissions from the user to read health data according to platform best practices.
*   Fetch exercise session/workout records, including associated data like distance, calories burned, and heart rate where available.
*   Return the fetched data in a consistent structured format (JSON) to the Cordova application.

**Target Platforms:** Android, iOS
