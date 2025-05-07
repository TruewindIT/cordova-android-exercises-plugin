# Technical Context: Cordova Health Exercises Plugin (Android & iOS)

**Core Technologies:**

*   **Cordova:** Hybrid application framework used to build the plugin structure and bridge JavaScript to native code.
    *   Targeted Platforms: `cordova-android`, `cordova-ios`.
*   **Android Native Development:**
    *   **Language:** Kotlin (version inferred from `build.gradle` dependencies, likely 1.7.1+ based on coroutines version).
    *   **Build System:** Gradle.
*   **iOS Native Development:**
    *   **Language:** Objective-C.
    *   **Build System:** Xcode (managed via Cordova CLI and `plugin.xml`).
*   **Android Health Connect SDK:** The primary API for accessing health and fitness data on Android.
    *   Version: `androidx.health.connect:connect-client:1.1.0-alpha07` (specified in `android/build.gradle`).
    *   Key Components Used: `HealthConnectClient`, `PermissionController`, `HealthPermission`, `ExerciseSessionRecord`, `ReadRecordsRequest`, `TimeRangeFilter`.
*   **Apple HealthKit Framework (iOS):** The primary API for accessing health and fitness data on iOS.
    *   Key Components Used: `HKHealthStore`, `HKObjectType`, `HKWorkoutType`, `HKQuantityType`, `HKSampleQuery`, `HKStatisticsQuery`, `NSPredicate`, `NSSortDescriptor`.
*   **Kotlin Coroutines:** Used for managing asynchronous operations on Android.
    *   Version: `org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1`.
*   **Serialization Libraries:**
    *   Android: **Gson** (`com.google.code.gson:gson:2.8.9`).
    *   iOS: **NSJSONSerialization**.
*   **Other iOS Frameworks:**
    *   **Foundation:** Used for `ISO8601DateFormatter`, `dispatch_group_t`, `NSJSONSerialization`.

        // Add specific checks for newer types if necessary, although mapping should handle them
        // Example for underwaterDiving if it needed special naming and was iOS 16+
        // if #available(iOS 16.0, *), self == .underwaterDiving { return "Underwater Diving" }

**Development Setup & Build:**

*   Requires a standard Cordova development environment setup for the target platforms (Android SDK, Gradle, macOS, Xcode, iOS SDK, Node.js/npm).
*   **Android:**
    *   Build managed by Gradle. `compileSdkVersion` needs confirmation (likely 33+).
    *   `plugin.xml` influences build via `<preference>` tags and `<framework>` tag for `android/build.gradle`.
*   **iOS:**
    *   Build managed by Xcode via Cordova CLI.
    *   `plugin.xml` configures framework linking (`HealthKit.framework`), `Info.plist` usage descriptions, includes `cordova-plugin-add-swift-support` dependency, and configures HealthKit entitlements directly using `<config-file target="*/Entitlements-*.plist">`.

**Technical Constraints & Dependencies:**

*   **Platform Health Service Availability:**
    *   Android: Requires Health Connect app installed. Checked via `isHealthConnectAvailable()`.
    *   iOS: Requires device/simulator supporting HealthKit. Checked via `HKHealthStore.isHealthDataAvailable()`.
*   **OS Versions:**
    *   Android: Health Connect requires API 28+ (Android 9+). Plugin `minSdkVersion` needs verification (currently 24 in commented code).
    *   iOS: Requires iOS version supporting HealthKit (iOS 8+). Specific distance types require higher versions (e.g., 11.0, 11.2, 18.0 - checked using `#available`).
*   **Permissions:**
    *   Android: Requires Health Connect read permissions declared in `AndroidManifest.xml` (via `plugin.xml`) and granted at runtime.
    *   iOS: Requires `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` in `Info.plist` (via `plugin.xml`) and user authorization via `requestAuthorization`. Requires `com.apple.developer.healthkit` entitlement, configured directly in `plugin.xml`.
*   **Android Build Environment:** Potential build errors related to `compileSdkVersion`, Kotlin versions, AndroidX compatibility, or Gradle configuration. The `android/build.gradle` is likely incomplete.
*   **Apple Developer Account:** May be required for testing on physical iOS devices. Provisioning profile must include HealthKit capability.
*   **Implementation Risks (iOS):** Potential retain cycle risk with Objective-C blocks if `__weak` or `__unsafe_unretained` is not used. Result aggregation relies on implicit `dispatch_group_notify` queue behavior, risking race conditions under load.

**Tool Usage Patterns:**

*   `cordova.exec`: Standard Cordova mechanism for JS-to-native communication.
*   **Android:**
    *   `HealthConnectClient`: Checking availability, requesting permissions, reading records.
    *   Kotlin Coroutines (`runBlocking`, `async`, `launch`): Asynchronous operations.
    *   Gson: JSON serialization.
*   **iOS:**
    *   `HKHealthStore`: Checking availability, requesting authorization, executing queries.
    *   `HKSampleQuery`: Fetching workout and heart rate sample data.
    *   `HKStatisticsQuery`: Calculating sum for active energy, basal energy, and distance.
    *   `NSJSONSerialization`: JSON serialization (Objective-C).
    *   `dispatch_async(dispatch_get_main_queue(), ^{...})`: Ensuring Cordova callbacks happen on the main thread.
    *   `dispatch_group_t`: Managing multiple asynchronous HealthKit queries for each workout.
    *   `@available`: Objective-C check for OS-specific API availability.
    *   (Note: Potential retain cycle risk with blocks if `__weak` or `__unsafe_unretained` is not used).
    *   (Note: Result aggregation relies on implicit thread safety).
