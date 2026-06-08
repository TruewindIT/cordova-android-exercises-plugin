# Branch Comparison: `main` vs. `alt-permissions`

This document explains the differences, architecture, and purpose of the **`alt-permissions`** branch compared to the **`main`** branch of the Cordova Exercises Health Plugin.

---

## 🎯 Purpose of `alt-permissions`

The `alt-permissions` branch was created for a specific enterprise client. It is designed to satisfy **strict privacy, security, and user-consent guidelines** regarding location tracking and unauthorized data manipulation.

While the `main` branch requests route tracking and data write privileges, the `alt-permissions` branch:
1. **Omit all WRITE permissions**: Operates strictly in a read-only capacity.
2. **Excludes Exercise Route collection**: Completely excludes any requests, mappings, or database queries for route/GPS location data (`READ_EXERCISE_ROUTE` / `HKWorkoutRoute`) across both Android and iOS.
3. **Retains Heart Rate collection**: Restores full biometric heart rate reads as in earlier alternate versions.

---

## 🔍 Detailed Differences

### 1. Requested Permissions

| Platform | `main` Branch | `alt-permissions` Branch | Purpose of Exclusion |
| :--- | :--- | :--- | :--- |
| **Android (Health Connect)** | Requests `WRITE_STEPS`, `WRITE_EXERCISE`, `WRITE_EXERCISEROUTE` | **Omitted** | Prevents modifying records in the health store |
| **Android (Health Connect)** | Requests `READ_EXERCISE_ROUTE` | **Omitted** | Prevents prompt/access to GPS workout route data |
| **iOS (HealthKit)** | Requests `[HKSeriesType workoutRouteType]` | **Omitted** | Prevents prompt/access to workout GPS route data |

*Android Manifest permissions and iOS Info.plist descriptions are automatically optimized on each branch to match only the declared permissions.*

---

## 🚀 When to Use Which?

*   Use **`main`** for standard fitness, health monitoring, or wellness apps where full workout telemetry (including GPS route tracking and writing completed workouts back) is desired.
*   Use **`alt-permissions`** for corporate wellness portals, read-only dashboard integrations, or enterprise environments where location tracking is legally restricted or writing to the device health store is prohibited.
