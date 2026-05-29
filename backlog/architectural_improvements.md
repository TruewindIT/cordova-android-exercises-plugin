# Architectural Backlog: Plugin Improvements Roadmap

This backlog outlines planned non-breaking architectural enhancements for the **Cordova Exercises Health Plugin** under the `main` branch. 

These tasks aim to optimize thread concurrency on Android and unify the `alt-permissions` and `main` branches into a single codebase via dynamic JS configurations—**while keeping the serialized JSON output structure 100% identical and unchanged**.

---

## 📋 Task 1: Unify Branches via Dynamic JS Permissions
**Goal**: Consolidate the `alt-permissions` branch into the `main` branch by allowing client-side customization of requested permissions at runtime, eliminating the need to maintain two Git branches.

### Proposed JS API Change
Modify `requestPermissions` to accept an optional options object:
```javascript
// Default: Requests full permissions (Equivalent to 'main')
cordova.plugins.RequestExercisePermissionsPlugin.requestPermissions(success, error);

// Custom: Omit sensitive biometric permissions (Equivalent to 'alt-permissions')
cordova.plugins.RequestExercisePermissionsPlugin.requestPermissions(
    { includeHeartRate: false }, 
    success, 
    error
);
```

### Dynamic Permissions Specification

Below is the list of native permissions that must be compiled and requested in each scenario:

#### **Scenario A: `main` (Full Telemetry)**
*   **Android (Health Connect)**:
    *   `HealthPermission.getReadPermission(StepsRecord::class)`
    *   `HealthPermission.getReadPermission(ExerciseSessionRecord::class)`
    *   `HealthPermission.getReadPermission(DistanceRecord::class)`
    *   `HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class)`
    *   `HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)`
    *   `HealthPermission.getReadPermission(HeartRateRecord::class)`
*   **iOS (HealthKit)**:
    *   `[HKObjectType workoutType]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCycling]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceSwimming]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWheelchair]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate]`

#### **Scenario B: `alt-permissions` (No Heart Rate)**
*   **Android (Health Connect)**:
    *   `HealthPermission.getReadPermission(StepsRecord::class)`
    *   `HealthPermission.getReadPermission(ExerciseSessionRecord::class)`
    *   `HealthPermission.getReadPermission(DistanceRecord::class)`
    *   `HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class)`
    *   `HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)`
    *   *Note: `HeartRateRecord` is completely omitted.*
*   **iOS (HealthKit)**:
    *   `[HKObjectType workoutType]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCycling]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceSwimming]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWheelchair]`
    *   `[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount]`
    *   *Note: `HKQuantityTypeIdentifierHeartRate` is completely omitted.*

---

## 📋 Task 2: Android Thread Concurrency Optimization (ANR Prevention)
**Goal**: Prevent potential thread blocking on Cordova's WebCore thread during large historical database queries by migrating away from Kotlin's blocking thread scopes.

### Implementation Blueprint
1.  **Remove `runBlocking`**: Remove blocking scopes inside `execute` and `getExerciseData`.
2.  **Cordova Thread Pool**: Run all query activities asynchronously within Cordova's managed native thread pool:
    ```kotlin
    override fun execute(
        action: String,
        args: JSONArray,
        callbackContext: CallbackContext
    ): Boolean {
        if (action == "getExerciseData") {
            val startTime = Instant.parse(args.getString(0))
            val endTime = Instant.parse(args.getString(1))
            
            // Execute non-blocking in background pool
            cordova.getThreadPool().execute {
                try {
                    // Perform asynchronous database reads and format JSON response...
                    callbackContext.success(jsonResult)
                } catch (e: Exception) {
                    callbackContext.error(e.message)
                }
            }
            return true
        }
        return false
    }
    ```
3.  **Impact**: Zero changes to the JavaScript API and zero changes to the JSON structure. It strictly improves background concurrency and app stability under Android.
