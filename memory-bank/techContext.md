# Technical Context: Cordova Health Exercises Plugin (Android & iOS)

**Core Technologies:**

*   **Cordova:** Hybrid application framework used to build the plugin structure and bridge JavaScript to native code.
    *   Targeted Platforms: `cordova-android`, `cordova-ios`.
*   **Android Native Development:**
    *   **Language:** Kotlin (version inferred from `build.gradle` dependencies, likely 1.7.1+ based on coroutines version).
    *   **Build System:** Gradle.
*   **iOS Native Development:**
    *   **Language:** Swift (Assumed latest stable compatible with target Xcode/iOS versions).
    *   **Build System:** Xcode (managed via Cordova CLI and `plugin.xml`).
*   **Android Health Connect SDK:** The primary API for accessing health and fitness data on Android.
    *   Version: `androidx.health.connect:connect-client:1.1.0-alpha07` (specified in `android/build.gradle`).
    *   Key Components Used: `HealthConnectClient`, `PermissionController`, `HealthPermission`, `ExerciseSessionRecord`, `ReadRecordsRequest`, `TimeRangeFilter`.
*   **Apple HealthKit Framework (iOS):** The primary API for accessing health and fitness data on iOS.
    *   Key Components Used: `HKHealthStore`, `HKObjectType`, `HKWorkoutType`, `HKQuantityType`, `HKSampleQuery`, `NSPredicate`, `NSSortDescriptor`.
*   **Kotlin Coroutines:** Used for managing asynchronous operations on Android.
    *   Version: `org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1`.
*   **Serialization Libraries:**
    *   Android: **Gson** (`com.google.code.gson:gson:2.8.9`).
    *   iOS: **Foundation.JSONSerialization**.
*   **Other iOS Frameworks:**
    *   **Foundation:** Used for `ISO8601DateFormatter`, `DispatchQueue`, `JSONSerialization`.
*   **Node.js Modules (for Hooks):**
    *   `plist`: Used by iOS hook script to parse/build `.entitlements` file. Version: `^3.1.0`.
    *   `xcode`: Used by iOS hook script to parse/modify `.pbxproj` file. Version: `^3.0.1`.

**Development Setup & Build:**

*   Requires a standard Cordova development environment setup for the target platforms (Android SDK, Gradle, macOS, Xcode, iOS SDK, Node.js/npm).
*   **Android:**
    *   Build managed by Gradle. `compileSdkVersion` needs confirmation (likely 33+).
    *   `plugin.xml` influences build via `<preference>` tags and `<framework>` tag for `android/build.gradle`.
*   **iOS:**
    *   Build managed by Xcode via Cordova CLI.
    *   `plugin.xml` configures framework linking (`HealthKit.framework`), `Info.plist` entries, and includes `cordova-plugin-add-swift-support` dependency.
    *   An `after_prepare` hook script (`scripts/ios/add_healthkit_entitlement.js`) modifies the `.entitlements` file and `.pbxproj` build settings to ensure HealthKit capability is enabled. Requires Node.js and hook dependencies (`plist`, `xcode`) to be installed in the plugin directory.

**Technical Constraints & Dependencies:**

*   **Platform Health Service Availability:**
    *   Android: Requires Health Connect app installed. Checked via `isHealthConnectAvailable()`.
    *   iOS: Requires device/simulator supporting HealthKit. Checked via `HKHealthStore.isHealthDataAvailable()`.
*   **OS Versions:**
    *   Android: Health Connect requires API 28+ (Android 9+). Plugin `minSdkVersion` needs verification (currently 24 in commented code).
    *   iOS: Requires iOS version supporting HealthKit (iOS 8+). Specific distance types require higher versions (e.g., 11.0, 11.2, 18.0 - checked using `#available`).
*   **Permissions:**
    *   Android: Requires Health Connect read permissions declared in `AndroidManifest.xml` (via `plugin.xml`) and granted at runtime.
    *   iOS: Requires `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` in `Info.plist` (via `plugin.xml`) and user authorization via `requestAuthorization`. Requires `com.apple.developer.healthkit` entitlement, managed by the hook script.
*   **Android Build Environment:** Potential build errors related to `compileSdkVersion`, Kotlin versions, AndroidX compatibility, or Gradle configuration. The `android/build.gradle` is likely incomplete.
*   **Apple Developer Account:** May be required for testing on physical iOS devices. Provisioning profile must include HealthKit capability.
*   **Hook Dependencies:** The iOS entitlement hook requires `plist` and `xcode` Node modules to be installed (`npm install` in plugin directory).

**Tool Usage Patterns:**

*   `cordova.exec`: Standard Cordova mechanism for JS-to-native communication.
*   **Android:**
    *   `HealthConnectClient`: Checking availability, requesting permissions, reading records.
    *   Kotlin Coroutines (`runBlocking`, `async`, `launch`): Asynchronous operations.
    *   Gson: JSON serialization.
*   **iOS:**
    *   `HKHealthStore`: Checking availability, requesting authorization, executing queries.
    *   `HKSampleQuery`: Fetching workout data.
    *   `JSONSerialization`: JSON serialization (Swift).
    *   `DispatchQueue.main.async`: Ensuring Cordova callbacks happen on the main thread (Swift).
    *   `#available`: Swift check for OS-specific API availability.
    *   `plist` (Node.js module): Used by hook script to manage `.entitlements` file.
    *   `xcode` (Node.js module): Used by hook script to manage `.pbxproj` file settings.
