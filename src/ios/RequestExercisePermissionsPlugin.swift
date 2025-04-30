import Cordova
import HealthKit

@objc(RequestExercisePermissionsPlugin) class RequestExercisePermissionsPlugin : CDVPlugin {

    let healthStore = HKHealthStore()

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

        // Define base types
        var readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            // Add all relevant distance types we might query later
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
        ]

        // Add distance types available in newer OS versions conditionally
        if #available(iOS 18.0, *) {
            // Note: Ensure this identifier truly requires iOS 18+ based on latest Apple docs if issues arise
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distanceRowing)!)
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distancePaddleSports)!)
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distanceSkatingSports)!)
            
            if let type = HKObjectType.quantityType(forIdentifier: .distanceCrossCountrySkiing) { readTypes.insert(type) }
        }
        if #available(iOS 11.2, *) {
             if let type = HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports) { readTypes.insert(type) }
        }
        // Add other distance types here if needed

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
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Authorization request processed.")
                } else {
                    print("Warning: HealthKit authorization request process failed without error.")
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Authorization denied or failed")
                }
            }
            DispatchQueue.main.async {
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    // MARK: - Get Exercise Data

    @objc(getExerciseData:)
    func getExerciseData(command: CDVInvokedUrlCommand) {
        print("Debug: getExerciseData called")

        guard HKHealthStore.isHealthDataAvailable() else {
            sendError(message: "HealthKit not available", command: command)
            return
        }

        // Check Authorization Status
        let workoutType = HKObjectType.workoutType()
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        // Distance status checked dynamically in fetchSamples

        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let activeEnergyStatus = healthStore.authorizationStatus(for: activeEnergyType)
        let basalEnergyStatus = healthStore.authorizationStatus(for: basalEnergyType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)

        print("""
            Debug: Auth Status Check (Core):
            Workout: \(workoutStatus.rawValue), \
            ActiveEnergy: \(activeEnergyStatus.rawValue), \
            BasalEnergy: \(basalEnergyStatus.rawValue), \
            HR: \(heartRateStatus.rawValue)
            """)

        guard workoutStatus != .notDetermined &&
              activeEnergyStatus != .notDetermined &&
              // basalEnergyStatus != .notDetermined && // Basal might not be granted/needed
              heartRateStatus != .notDetermined else {
            var notDeterminedTypes = [String]()
             if workoutStatus == .notDetermined { notDeterminedTypes.append("Workouts") }
             if activeEnergyStatus == .notDetermined { notDeterminedTypes.append("Active Energy") }
             // if basalEnergyStatus == .notDetermined { notDeterminedTypes.append("Basal Energy") }
             if heartRateStatus == .notDetermined { notDeterminedTypes.append("Heart Rate") }
            let errorMessage = "HealthKit authorization status not determined for essential types: \(notDeterminedTypes.joined(separator: ", ")). Please request permissions first."
            sendError(message: errorMessage, command: command)
            return
        }

        // Parse Arguments
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

        // Prepare Main Workout Query
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
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "[]")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                return
            }

            print("Info: Found \(workouts.count) workouts. Fetching detailed samples...")

            // Process Each Workout with Sub-Queries
            var finalResults = [[String: Any]]()
            let allWorkoutsGroup = DispatchGroup()
            // Using a serial queue for appending results to avoid race conditions simply.
            let resultsQueue = DispatchQueue(label: "com.axians.plugin.resultsQueue")

            for workout in workouts {
                allWorkoutsGroup.enter()
                self.fetchSamples(for: workout) { workoutDetailDict in
                    if let workoutDetailDict = workoutDetailDict {
                        resultsQueue.async { // Append results serially
                            finalResults.append(workoutDetailDict)
                            allWorkoutsGroup.leave()
                        }
                    } else {
                         print("Warning: Failed to fetch details for workout UUID: \(workout.uuid.uuidString)")
                         allWorkoutsGroup.leave() // Leave even if fetching details failed
                    }
                }
            }

            // Wait for all workouts and send final result
            allWorkoutsGroup.notify(queue: .main) {
                print("Info: Finished processing all workouts (\(finalResults.count)). Serializing and sending result.")
                // Access finalResults safely after all appends are done by ensuring notify waits
                resultsQueue.async { // Ensure sorting happens after all appends
                    do {
                        let sortedResults = finalResults.sorted { (dict1, dict2) -> Bool in
                            guard let dateStr1 = dict1["startDate"] as? String,
                                  let dateStr2 = dict2["startDate"] as? String,
                                  let date1 = dateFormatter.date(from: dateStr1),
                                  let date2 = dateFormatter.date(from: dateStr2) else { return false }
                            return date1 > date2 // Descending
                        }

                        let jsonData = try JSONSerialization.data(withJSONObject: sortedResults, options: [])
                        if let jsonString = String(data: jsonData, encoding: .utf8) {
                            // Switch back to main thread for Cordova callback
                            DispatchQueue.main.async {
                                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonString)
                                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                            }
                        } else {
                            self.sendError(message: "Failed to encode final results to JSON string", command: command)
                        }
                    } catch {
                        self.sendError(message: "Failed to serialize final results: \(error.localizedDescription)", command: command)
                    }
                } // End resultsQueue.async
            } // End allWorkoutsGroup.notify
        }
        healthStore.execute(workoutQuery)
    }

    // MARK: - Sample Fetching Helper

    private func fetchSamples(for workout: HKWorkout, completion: @escaping ([String: Any]?) -> Void) {
        let sampleGroup = DispatchGroup()
        var activeCaloriesSum: Double? = nil
        var basalCaloriesSum: Double? = nil
        var distanceSum: Double? = nil
        var heartRateValues: [Double]? = nil

        let workoutPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)

        // Define Types and Units
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let energyUnit = HKUnit.kilocalorie()
        let distanceUnit = HKUnit.meter()
        let hrUnit = HKUnit.count().unitDivided(by: .minute())

        // --- Query Active Calories Sum ---
        sampleGroup.enter()
        let activeCaloriesQuery = HKStatisticsQuery(quantityType: activeEnergyType,
                                                    quantitySamplePredicate: workoutPredicate,
                                                    options: .cumulativeSum) { _, result, error in
            defer { sampleGroup.leave() }
            if let error = error { print("Error querying active calories: \(error.localizedDescription)"); return }
            activeCaloriesSum = result?.sumQuantity()?.doubleValue(for: energyUnit)
            print("Debug: Active calories sum for workout \(workout.uuid.uuidString): \(activeCaloriesSum ?? -1)")
        }
        healthStore.execute(activeCaloriesQuery)

        // --- Query Basal Calories Sum ---
        sampleGroup.enter()
        let basalCaloriesQuery = HKStatisticsQuery(quantityType: basalEnergyType,
                                                   quantitySamplePredicate: workoutPredicate,
                                                   options: .cumulativeSum) { _, result, error in
            defer { sampleGroup.leave() }
            if let error = error { print("Error querying basal calories: \(error.localizedDescription)"); return }
            basalCaloriesSum = result?.sumQuantity()?.doubleValue(for: energyUnit)
            print("Debug: Basal calories sum for workout \(workout.uuid.uuidString): \(basalCaloriesSum ?? -1)")
        }
        healthStore.execute(basalCaloriesQuery)

        // --- Query Distance Sum (Dynamically Typed) ---
        if let distanceType = getDistanceType(for: workout.workoutActivityType) {
             let distanceStatus = healthStore.authorizationStatus(for: distanceType)
             print("Debug: Auth status for \(distanceType.identifier): \(distanceStatus.rawValue)")
            // Proceed if permission is granted OR denied (per user request)
            if distanceStatus == .sharingAuthorized || distanceStatus == .sharingDenied {
                 sampleGroup.enter()
                 let distanceQuery = HKStatisticsQuery(quantityType: distanceType,
                                                       quantitySamplePredicate: workoutPredicate,
                                                       options: .cumulativeSum) { _, result, error in
                     defer { sampleGroup.leave() }
                     if let error = error { print("Error querying distance (\(distanceType.identifier)): \(error.localizedDescription)"); return }
                     distanceSum = result?.sumQuantity()?.doubleValue(for: distanceUnit)
                     print("Debug: Distance sum (\(distanceType.identifier)) for workout \(workout.uuid.uuidString): \(distanceSum ?? -1)")
                 }
                 healthStore.execute(distanceQuery)
             } else {
                 print("Warning: Distance type \(distanceType.identifier) has status .notDetermined, skipping query.")
             }
        } else {
            print("Debug: No specific distance type associated with activity type \(workout.workoutActivityType.name), skipping distance query.")
        }


        // --- Query Heart Rate Samples ---
        sampleGroup.enter()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let hrQuery = HKSampleQuery(sampleType: heartRateType,
                                    predicate: workoutPredicate,
                                    limit: HKObjectQueryNoLimit,
                                    sortDescriptors: [sortDescriptor]) { _, samples, error in
            defer { sampleGroup.leave() }
            if let error = error { print("Error querying heart rates: \(error.localizedDescription)"); return }
            if let hrSamples = samples as? [HKQuantitySample] {
                heartRateValues = hrSamples.map { $0.quantity.doubleValue(for: hrUnit) }
                 print("Debug: Found \(heartRateValues?.count ?? 0) heart rate samples for workout \(workout.uuid.uuidString)")
            } else {
                 heartRateValues = []
                 print("Debug: No heart rate samples found or cast failed for workout \(workout.uuid.uuidString)")
            }
        }
        healthStore.execute(hrQuery)

        // --- Notify when all sample queries are done ---
        sampleGroup.notify(queue: .global()) {
             print("Debug: Sample queries finished for workout \(workout.uuid.uuidString). Formatting output.")
             let dateFormatter = ISO8601DateFormatter()
             dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
             let workoutStartDateStr = dateFormatter.string(from: workout.startDate)
             let workoutEndDateStr = dateFormatter.string(from: workout.endDate)

             // --- Construct Samples Array ---
             var samplesArray = [[String: Any]]()
             let activeCaloriesSample: [String: Any] = [
                 "startDate": workoutStartDateStr, "endDate": workoutEndDateStr, "block": 1,
                 "values": [activeCaloriesSum ?? 0.0], "additionalData": "ACTIVE_CALORIES_BURNED"
             ]
             samplesArray.append(activeCaloriesSample)
             let heartRateSample: [String: Any] = [
                 "startDate": workoutStartDateStr, "endDate": workoutEndDateStr, "block": 1,
                 "values": heartRateValues ?? [], "additionalData": "HEART_RATE"
             ]
             samplesArray.append(heartRateSample)

             // --- Construct Main Workout Dictionary ---
             let totalCalculatedEnergy = (activeCaloriesSum ?? 0.0) + (basalCaloriesSum ?? 0.0)
             let totalCalculatedDistance = distanceSum ?? 0.0

             let workoutDict: [String: Any] = [
                 "startDate": workoutStartDateStr,
                 "endDate": workoutEndDateStr,
                 "duration": workout.duration,
                 "activity": workout.workoutActivityType.name,
                 "totalDistance": totalCalculatedDistance,
                 "totalEnergyBurned": totalCalculatedEnergy,
                 "samples": samplesArray
             ]
             completion(workoutDict)
        }
    }


    // MARK: - Helper Functions

    // Helper function to determine appropriate distance type based on workout activity
    private func getDistanceType(for activityType: HKWorkoutActivityType) -> HKQuantityType? {
        switch activityType {
        case .running, .walking, .hiking: // Group walking/running types
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .cycling, .handCycling: // Group cycling types
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case .swimming:
            return HKObjectType.quantityType(forIdentifier: .distanceSwimming)
        case .wheelchairRunPace, .wheelchairWalkPace: // Group wheelchair types
             return HKObjectType.quantityType(forIdentifier: .distanceWheelchair)
        case .rowing:
             if #available(iOS 18.0, *) { // Check availability
             return HKObjectType.quantityType(forIdentifier: .distanceRowing)
             } else { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        case .paddleSports:
             if #available(iOS 18.0, *) { // Check availability
             return HKObjectType.quantityType(forIdentifier: .distancePaddleSports)
             } else { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        case .skatingSports:
             if #available(iOS 18.0, *) { // Check availability
             return HKObjectType.quantityType(forIdentifier: .distanceSkatingSports)
             } else { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        case .crossCountrySkiing:
             if #available(iOS 18.0, *) { // Check availability
                 return HKObjectType.quantityType(forIdentifier: .distanceCrossCountrySkiing)
             } else { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        case .downhillSkiing, .snowboarding, .snowSports: // Group snow sports
             if #available(iOS 11.2, *) { // Check availability
                 return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)
             } else { return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) }
        default:
            // Return nil if no specific distance type is typically associated
            print("Debug: No distance type mapping for activity: \(activityType.name)")
            return nil
        }
    }

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
            .other: "Other"
        ]
        return mapping[self] ?? "Unknown Activity (\(self.rawValue))"
    }
}
