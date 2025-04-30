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

        var readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!, // Added for total energy calculation
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!
        ]

        // Add distance types available in newer OS versions conditionally
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

        // 1. Check HealthKit availability
        guard HKHealthStore.isHealthDataAvailable() else {
            sendError(message: "HealthKit not available", command: command)
            return
        }

        // 2. Check Authorization Status
        let workoutType = HKObjectType.workoutType()
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)! // Using representative distance type
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let activeEnergyStatus = healthStore.authorizationStatus(for: activeEnergyType)
        let basalEnergyStatus = healthStore.authorizationStatus(for: basalEnergyType) // Check basal too
        let distanceStatus = healthStore.authorizationStatus(for: distanceType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)

        print("""
            Debug: Auth Status Check:
            Workout: \(workoutStatus.rawValue), \
            ActiveEnergy: \(activeEnergyStatus.rawValue), \
            BasalEnergy: \(basalEnergyStatus.rawValue), \
            Distance: \(distanceStatus.rawValue), \
            HR: \(heartRateStatus.rawValue)
            """)

        // Check if essential types have been determined (not .notDetermined)
        // Note: Basal energy might not always be available or authorized, handle gracefully later
        guard workoutStatus != .notDetermined &&
              activeEnergyStatus != .notDetermined &&
              // basalEnergyStatus != .notDetermined && // Optional: Basal might not be granted/needed if totalEnergyBurned on workout is used as fallback
              distanceStatus != .notDetermined &&
              heartRateStatus != .notDetermined else {
            var notDeterminedTypes = [String]()
             if workoutStatus == .notDetermined { notDeterminedTypes.append("Workouts") }
             if activeEnergyStatus == .notDetermined { notDeterminedTypes.append("Active Energy") }
             // if basalEnergyStatus == .notDetermined { notDeterminedTypes.append("Basal Energy") }
             if distanceStatus == .notDetermined { notDeterminedTypes.append("Distance") }
             if heartRateStatus == .notDetermined { notDeterminedTypes.append("Heart Rate") }
            let errorMessage = "HealthKit authorization status not determined for essential types: \(notDeterminedTypes.joined(separator: ", ")). Please request permissions first."
            sendError(message: errorMessage, command: command)
            return
        }

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
                let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "[]")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                return
            }

            print("Info: Found \(workouts.count) workouts. Fetching detailed samples...")

            // 5. Process Each Workout with Sub-Queries
            var finalResults = [[String: Any]]()
            let allWorkoutsGroup = DispatchGroup()
            let resultsQueue = DispatchQueue(label: "com.axians.plugin.resultsQueue", attributes: .concurrent)

            for workout in workouts {
                allWorkoutsGroup.enter()
                self.fetchSamples(for: workout) { workoutDetailDict in
                    if let workoutDetailDict = workoutDetailDict {
                        resultsQueue.async(flags: .barrier) {
                            finalResults.append(workoutDetailDict)
                            allWorkoutsGroup.leave()
                        }
                    } else {
                         print("Warning: Failed to fetch details for workout UUID: \(workout.uuid.uuidString)")
                         allWorkoutsGroup.leave()
                    }
                }
            }

            // 6. Wait for all workouts and send final result
            allWorkoutsGroup.notify(queue: .main) {
                print("Info: Finished processing all workouts (\(finalResults.count)). Serializing and sending result.")
                resultsQueue.sync {
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
        }

        // 7. Execute the Main Workout Query
        healthStore.execute(workoutQuery)
    }

    // MARK: - Sample Fetching Helper

    private func fetchSamples(for workout: HKWorkout, completion: @escaping ([String: Any]?) -> Void) {
        let sampleGroup = DispatchGroup()
        var activeCaloriesSum: Double? = nil
        var basalCaloriesSum: Double? = nil
        var distanceSum: Double? = nil // Using a representative distance type sum
        var heartRateValues: [Double]? = nil

        let workoutPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)

        // Define Types and Units
        let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        let basalEnergyType = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        // Using distanceWalkingRunning as the representative type for the statistics query
        // TODO: Ideally, query the distance type corresponding to workout.workoutActivityType
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!

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

        // --- Query Distance Sum ---
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
             // Calculate total energy by summing active and basal (if available)
             let totalCalculatedEnergy = (activeCaloriesSum ?? 0.0) + (basalCaloriesSum ?? 0.0)
             // Use calculated distance sum
             let totalCalculatedDistance = distanceSum ?? 0.0

             let workoutDict: [String: Any] = [
                 "startDate": workoutStartDateStr,
                 "endDate": workoutEndDateStr,
                 "duration": workout.duration,
                 "activity": workout.workoutActivityType.name,
                 "totalDistance": totalCalculatedDistance, // Use calculated distance
                 "totalEnergyBurned": totalCalculatedEnergy, // Use calculated total energy
                 "samples": samplesArray
             ]
             completion(workoutDict)
        }
    }


    // MARK: - Helper Functions

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
