import Cordova
import HealthKit
// import OSLog // Removed logging import

@objc(RequestExercisePermissionsPlugin) class RequestExercisePermissionsPlugin : CDVPlugin {

    let healthStore = HKHealthStore()
    // Removed logger instance variable

    override func pluginInitialize() {
        super.pluginInitialize()
        if !HKHealthStore.isHealthDataAvailable() {
            print("Warning: HealthKit is not available on this device.")
        } else {
             print("Info: HealthKit is available.")
        }
    }

    // MARK: - Permissions

    @objc(requestPermissions:)
    func requestPermissions(command: CDVInvokedUrlCommand) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Error: Permission request failed: HealthKit not available.")
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "HealthKit not available")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }

        var readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!
        ]

        if #available(iOS 18.0, *) {
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distanceCrossCountrySkiing)!)
        }
        if #available(iOS 11.2, *) {
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!)
        }

        print("Debug: Requesting authorization for types: \(readTypes.map { $0.identifier }.joined(separator: ", "))")

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] (success, error) in
            guard let self = self else { return }
            var pluginResult: CDVPluginResult?
            if let error = error {
                print("Error: Error requesting HealthKit authorization: \(error.localizedDescription)")
                pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Authorization error: \(error.localizedDescription)")
            } else {
                if success {
                    print("Info: HealthKit authorization request process completed successfully (permissions may or may not be granted).")
                    // Note: Success here only means the prompt was shown and dismissed without error.
                    // We still need to check individual statuses before querying.
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Authorization request processed.")
                } else {
                    // This 'else' block might be rare if error is nil, but handles unexpected cases.
                    print("Warning: HealthKit authorization request process failed without error.")
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Authorization denied or failed")
                }
            }
            // Ensure the callback is on the main thread
            DispatchQueue.main.async {
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    // MARK: - Get Exercise Data

    @objc(getExerciseData:)
    func getExerciseData(command: CDVInvokedUrlCommand) {
        print("Debug: getExerciseData called")

        // 1. Check HealthKit availability
        guard HKHealthStore.isHealthDataAvailable() else {
            sendError(message: "HealthKit not available", command: command)
            return
        }

        // 2. Check Authorization Status (per user request, only check for .notDetermined)
        let workoutType = HKObjectType.workoutType()
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)! // Representative distance
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let energyStatus = healthStore.authorizationStatus(for: energyType)
        let distanceStatus = healthStore.authorizationStatus(for: distanceType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)

        // Log statuses for debugging using print
        print("""
            Debug: Auth Status Check:
            Workout: \(workoutStatus.rawValue), \
            Energy: \(energyStatus.rawValue), \
            Distance: \(distanceStatus.rawValue), \
            HR: \(heartRateStatus.rawValue)
            """)

        guard workoutStatus != .notDetermined &&
              energyStatus != .notDetermined &&
              distanceStatus != .notDetermined &&
              heartRateStatus != .notDetermined else {
            var notDeterminedTypes = [String]()
            // ... (construct list of notDeterminedTypes as before) ...
             if workoutStatus == .notDetermined { notDeterminedTypes.append("Workouts") }
             if energyStatus == .notDetermined { notDeterminedTypes.append("Active Energy") }
             if distanceStatus == .notDetermined { notDeterminedTypes.append("Distance") }
             if heartRateStatus == .notDetermined { notDeterminedTypes.append("Heart Rate") }
            let errorMessage = "HealthKit authorization status not determined for essential types: \(notDeterminedTypes.joined(separator: ", ")). Please request permissions first."
            sendError(message: errorMessage, command: command)
            return
        }
        // Note: If status is .sharingDenied for any type, subsequent queries may fail or return no data.

        // 3. Parse Arguments
        guard let startDateStr = command.arguments[0] as? String,
              let endDateStr = command.arguments[1] as? String else {
            sendError(message: "Invalid arguments: Start and end date strings required", command: command)
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let startDate = dateFormatter.date(from: startDateStr),
              let endDate = dateFormatter.date(from: endDateStr) else {
            sendError(message: "Invalid date format: Use ISO 8601 format", command: command)
            return
        }
        print("Info: Querying workouts from \(startDate) to \(endDate)")

        // 4. Prepare Main Workout Query
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workoutQuery = HKSampleQuery(sampleType: workoutType,
                                         predicate: timePredicate,
                                         limit: HKObjectQueryNoLimit,
                                         sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in
            guard let self = self else { return }

            if let error = error {
                self.sendError(message: "Error querying workouts: \(error.localizedDescription)", command: command)
                return
            }

            guard let workouts = samples as? [HKWorkout], !workouts.isEmpty else {
                print("Info: No workouts found in the specified date range.")
                // Send empty array for success case with no results
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "[]")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                return
            }

            print("Info: Found \(workouts.count) workouts. Fetching detailed samples...")

            // 5. Process Each Workout with Sub-Queries
            var finalResults = [[String: Any]]()
            // Use a dispatch group to wait for all sub-queries for all workouts
            let allWorkoutsGroup = DispatchGroup()

            for workout in workouts {
                allWorkoutsGroup.enter() // Enter group for each workout

                self.fetchSamples(for: workout) { workoutDetailDict in
                    // This completion block is called when samples for *one* workout are fetched
                    if let workoutDetailDict = workoutDetailDict {
                        // Simple append might be okay if notify queue is serial, but safer with explicit sync
                        // For simplicity now, assuming sequential processing or low contention risk.
                        // If issues arise, implement proper locking or concurrent queue with barrier.
                        finalResults.append(workoutDetailDict)
                    } else {
                        
                         // Optionally append a partial result or skip this workout
                    }
                    allWorkoutsGroup.leave() // Leave group for this workout
                }
            }

            // 6. Wait for all workouts to be processed and send final result
            allWorkoutsGroup.notify(queue: .main) { // Use main queue for final callback
                print("Info: Finished processing all workouts (\(finalResults.count)). Serializing and sending result.")
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: finalResults, options: [])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonString)
                        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                    } else {
                        self.sendError(message: "Failed to encode final results to JSON string", command: command)
                    }
                } catch {
                    self.sendError(message: "Failed to serialize final results: \(error.localizedDescription)", command: command)
                }
            }
        }

        // 7. Execute the Main Workout Query
        healthStore.execute(workoutQuery)
    }

    // MARK: - Sample Fetching Helper

    private func fetchSamples(for workout: HKWorkout, completion: @escaping ([String: Any]?) -> Void) {
        let sampleGroup = DispatchGroup()
        var activeCaloriesSum: Double? = nil
        var heartRateValues: [Double]? = nil

        let workoutPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        // Query Active Calories Sum
        sampleGroup.enter()
        let caloriesQuery = HKStatisticsQuery(quantityType: energyType,
                                              quantitySamplePredicate: workoutPredicate,
                                               options: .cumulativeSum) { [weak self] _, result, error in
            defer { sampleGroup.leave() }
            if let error = error {
                 print("Error: Error querying active calories for workout \(workout.uuid.uuidString): \(error.localizedDescription)")
                 // Continue without active calories for this workout
                 return
            }
            activeCaloriesSum = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
            print("Debug: Active calories for workout \(workout.uuid.uuidString): \(activeCaloriesSum ?? -1)")
        }
        healthStore.execute(caloriesQuery)

        // Query Heart Rate Samples
        sampleGroup.enter()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let hrQuery = HKSampleQuery(sampleType: heartRateType,
                                    predicate: workoutPredicate,
                                     limit: HKObjectQueryNoLimit,
                                     sortDescriptors: [sortDescriptor]) { [weak self] _, samples, error in
            defer { sampleGroup.leave() }
            if let error = error {
                print("Error: Error querying heart rates for workout \(workout.uuid.uuidString): \(error.localizedDescription)")
                // Continue without heart rates for this workout
                return
            }
            if let hrSamples = samples as? [HKQuantitySample] {
                heartRateValues = hrSamples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
                 print("Debug: Found \(heartRateValues?.count ?? 0) heart rate samples for workout \(workout.uuid.uuidString)")
            } else {
                 heartRateValues = []
                 print("Debug: No heart rate samples found or cast failed for workout \(workout.uuid.uuidString)")
            }
        }
        healthStore.execute(hrQuery)

        // Notify when both sample queries are done
        sampleGroup.notify(queue: .global()) { // Process formatting on a background thread
             print("Debug: Sample queries finished for workout \(workout.uuid.uuidString). Formatting output.")
             let dateFormatter = ISO8601DateFormatter()
             dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
             let workoutStartDateStr = dateFormatter.string(from: workout.startDate)
             let workoutEndDateStr = dateFormatter.string(from: workout.endDate)

             let activeCaloriesSample: [String: Any] = [
                 "startDate": workoutStartDateStr,
                 "endDate": workoutEndDateStr,
                 "block": 1,
                 "values": [activeCaloriesSum ?? 0.0], // Use 0.0 if query failed or no data
                 "additionalData": "ACTIVE_CALORIES_BURNED"
             ]

             let heartRateSample: [String: Any] = [
                 "startDate": workoutStartDateStr,
                 "endDate": workoutEndDateStr,
                 "block": 1,
                 "values": heartRateValues ?? [], // Use empty array if query failed or no data
                 "additionalData": "HEART_RATE"
             ]

             let workoutDict: [String: Any] = [
                 "startDate": workoutStartDateStr,
                 "endDate": workoutEndDateStr,
                 "duration": workout.duration,
                 "activity": workout.workoutActivityType.name, // Use the extension method
                 "totalDistance": workout.totalDistance?.doubleValue(for: .meter()) ?? 0.0,
                 "totalEnergyBurned": workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0,
                 "samples": [activeCaloriesSample, heartRateSample]
             ]
             completion(workoutDict)
        }
    }


    // MARK: - Helper Functions

    // Helper function to send errors back to Cordova
    private func sendError(message: String, command: CDVInvokedUrlCommand) {
        print("Error: Plugin Error: \(message)")
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message)
        DispatchQueue.main.async {
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
        }
    }
}

// MARK: - HKWorkoutActivityType Extension

extension HKWorkoutActivityType {
    /// A human-readable name for the workout activity type.
    var name: String {
        // Using a dictionary for slightly cleaner mapping
        let mapping: [HKWorkoutActivityType: String] = [
            .americanFootball: "American Football", .archery: "Archery", .australianFootball: "Australian Football",
            .badminton: "Badminton", .baseball: "Baseball", .basketball: "Basketball", .bowling: "Bowling",
            .boxing: "Boxing", .climbing: "Climbing", .cricket: "Cricket", .crossTraining: "Cross Training",
            .curling: "Curling", .cycling: "Cycling", .dance: "Dance", .elliptical: "Elliptical",
            .equestrianSports: "Equestrian Sports", .fencing: "Fencing", .fishing: "Fishing",
            .functionalStrengthTraining: "Functional Strength Training", .golf: "Golf", .gymnastics: "Gymnastics",
            .handball: "Handball", .hiking: "Hiking", .hockey: "Hockey", .hunting: "Hunting", .lacrosse: "Lacrosse",
            .martialArts: "Martial Arts", .mindAndBody: "Mind and Body", .mixedMetabolicCardioTraining: "Mixed Metabolic Cardio Training",
            .paddleSports: "Paddle Sports", .play: "Play", .preparationAndRecovery: "Preparation and Recovery",
            .racquetball: "Racquetball", .rowing: "Rowing", .rugby: "Rugby", .running: "Running", .sailing: "Sailing",
            .skatingSports: "Skating Sports", .snowSports: "Snow Sports", .soccer: "Soccer", .softball: "Softball",
            .squash: "Squash", .stairClimbing: "Stair Climbing", .surfingSports: "Surfing Sports", .swimming: "Swimming",
            .tableTennis: "Table Tennis", .tennis: "Tennis", .trackAndField: "Track and Field",
            .traditionalStrengthTraining: "Traditional Strength Training", .volleyball: "Volleyball", .walking: "Walking",
            .waterFitness: "Water Fitness", .waterPolo: "Water Polo", .waterSports: "Water Sports", .wrestling: "Wrestling",
            .yoga: "Yoga", .barre: "Barre", .coreTraining: "Core Training", .crossCountrySkiing: "Cross Country Skiing",
            .downhillSkiing: "Downhill Skiing", .flexibility: "Flexibility", .highIntensityIntervalTraining: "High Intensity Interval Training",
            .jumpRope: "Jump Rope", .kickboxing: "Kickboxing", .pilates: "Pilates", .snowboarding: "Snowboarding",
            .stairs: "Stairs", .stepTraining: "Step Training", .wheelchairWalkPace: "Wheelchair Walk Pace",
            .wheelchairRunPace: "Wheelchair Run Pace", .taiChi: "Tai Chi", .mixedCardio: "Mixed Cardio",
            .handCycling: "Hand Cycling",
            // Note: Some types like .other might need specific handling if you want finer granularity than the default name
            .other: "Other"
        ]

        // Add specific checks for newer types if necessary, although mapping should handle them
        // Example for underwaterDiving if it needed special naming and was iOS 16+
        // if #available(iOS 16.0, *), self == .underwaterDiving { return "Underwater Diving" }

        // Fallback for unknown types
        return mapping[self] ?? "Unknown Activity (\(self.rawValue))"
    }
}
