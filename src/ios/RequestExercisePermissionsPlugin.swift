import Cordova
import HealthKit

@objc(RequestExercisePermissionsPlugin) class RequestExercisePermissionsPlugin : CDVPlugin {

    let healthStore = HKHealthStore()

    override func pluginInitialize() {
        super.pluginInitialize()
        // Check if HealthKit is available on this device.
        if !HKHealthStore.isHealthDataAvailable() {
            print("HealthKit is not available on this device.")
            // Optionally send a status back to JS or handle appropriately
        }
    }

    @objc(requestPermissions:)
    func requestPermissions(command: CDVInvokedUrlCommand) {
        guard HKHealthStore.isHealthDataAvailable() else {
            let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "HealthKit not available")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }

        // Define the health data types we want to read.
        // Note: HKWorkout already contains aggregated distance/energy, but requesting
        // specific quantity types ensures we have permission if we ever need to query
        // those samples directly or if the user expects to see them in the permission prompt.
        var readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            // Core types
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            // Distance Types
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
            HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
            HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
            // Note: As of iOS 16/watchOS 9, some specific distance types might be deprecated
            // or consolidated. Using the main ones covers most cases.
            // Let's add the specific ones requested, checking availability if possible,
            // although direct availability checks aren't standard for HKQuantityTypeIdentifier.
            // The requestAuthorization call handles unavailable types gracefully.
            // HKObjectType.quantityType(forIdentifier: .distanceRowing)!, // This identifier doesn't exist in HealthKit
            // HKObjectType.quantityType(forIdentifier: .distancePaddleSports)!, // This identifier doesn't exist
            // HKObjectType.quantityType(forIdentifier: .distanceSkatingSports)!, // This identifier doesn't exist
        ]

        // Add types available only in specific OS versions conditionally
        if #available(iOS 18.0, *) {
             // User specified iOS 18.0+ requirement
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distanceCrossCountrySkiing)!)
        }
        if #available(iOS 11.2, *) {
             // Introduced in iOS 11.2
            readTypes.insert(HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!)
        }
        // Add other version-specific types here if needed in the future

        // The HKWorkout object's totalDistance field should provide the relevant distance
        // regardless of the specific activity type if it was recorded.

        // Request authorization. We are not requesting share authorization (toShare: nil).
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { (success, error) in
            var pluginResult: CDVPluginResult?
            if let error = error {
                print("Error requesting HealthKit authorization: \(error.localizedDescription)")
                pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Authorization error: \(error.localizedDescription)")
            } else {
                if success {
                    print("HealthKit authorization request successful.")
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: "Authorization granted") // Or just OK status
                } else {
                    print("HealthKit authorization request denied or failed.")
                    pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Authorization denied or failed")
                }
            }
            // Ensure the callback is on the main thread
            DispatchQueue.main.async {
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc(getExerciseData:)
    func getExerciseData(command: CDVInvokedUrlCommand) {
        // 1. Check HealthKit availability and authorization
        guard HKHealthStore.isHealthDataAvailable() else {
            sendError(message: "HealthKit not available", command: command)
            return
        }

        // Check authorization status for essential types
        let workoutType = HKObjectType.workoutType()
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        // Using a common distance type for the check, assuming permission for one implies others were likely prompted.
        let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!

        let workoutStatus = healthStore.authorizationStatus(for: workoutType)
        let energyStatus = healthStore.authorizationStatus(for: energyType)
        let distanceStatus = healthStore.authorizationStatus(for: distanceType)
        let heartRateStatus = healthStore.authorizationStatus(for: heartRateType)

        // Log statuses for debugging
        // HKAuthorizationStatus raw values: 0 = notDetermined, 1 = sharingDenied, 2 = sharingAuthorized
        print("Auth Status - Workout: \(workoutStatus.rawValue), Energy: \(energyStatus.rawValue), Distance: \(distanceStatus.rawValue), HR: \(heartRateStatus.rawValue)")

        // Check if essential types have been determined (not .notDetermined)
        // Allows proceeding even if status is .sharingDenied, per user request.
        guard workoutStatus != .notDetermined &&
              energyStatus != .notDetermined &&
              distanceStatus != .notDetermined &&
              heartRateStatus != .notDetermined else {

            var notDeterminedTypes = [String]()
            if workoutStatus == .notDetermined { notDeterminedTypes.append("Workouts") }
            if energyStatus == .notDetermined { notDeterminedTypes.append("Active Energy") }
            if distanceStatus == .notDetermined { notDeterminedTypes.append("Distance") }
            if heartRateStatus == .notDetermined { notDeterminedTypes.append("Heart Rate") }

            let errorMessage = "HealthKit authorization status not determined for essential types: \(notDeterminedTypes.joined(separator: ", ")). Please request permissions first."
            sendError(message: errorMessage, command: command)
            return
        }
        // Note: If status is .sharingDenied for any type, the following query may fail or return no data.

        // 2. Parse arguments (expecting ISO 8601 date strings for start and end)
        guard let startDateStr = command.arguments[0] as? String,
              let endDateStr = command.arguments[1] as? String else {
            sendError(message: "Invalid arguments: Start and end date strings required", command: command)
            return
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // Adjust options as needed based on JS input format

        guard let startDate = dateFormatter.date(from: startDateStr),
              let endDate = dateFormatter.date(from: endDateStr) else {
            sendError(message: "Invalid date format: Use ISO 8601 format", command: command)
            return
        }

        // 3. Prepare the query
        let timePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false) // Get most recent first

        let query = HKSampleQuery(sampleType: workoutType,
                                  predicate: timePredicate,
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [sortDescriptor]) { [weak self] (query, samples, error) in

            guard let self = self else { return } // Avoid retain cycles

            // 4. Handle query results
            if let error = error {
                self.sendError(message: "Error querying workouts: \(error.localizedDescription)", command: command)
                return
            }

            guard let workouts = samples as? [HKWorkout] else {
                self.sendError(message: "Failed to process workout samples", command: command)
                return
            }

            // 5. Process workouts and prepare JSON data
            let workoutData = workouts.map { workout -> [String: Any] in
                var data: [String: Any] = [
                    "uuid": workout.uuid.uuidString,
                    "startDate": dateFormatter.string(from: workout.startDate),
                    "endDate": dateFormatter.string(from: workout.endDate),
                    "duration": workout.duration, // in seconds
                    "workoutActivityType": workout.workoutActivityType.name, // Raw integer value
                    // Consider adding a helper to map rawValue to a string description if needed
                    "sourceRevision": [ // Info about the app that saved the data
                        "source": workout.sourceRevision.source.name,
                        "version": workout.sourceRevision.version ?? "",
                        "productType": workout.sourceRevision.productType ?? "",
                        "bundleIdentifier": workout.sourceRevision.source.bundleIdentifier
                    ]
                ]
                // Add aggregated stats if available
                if let totalEnergy = workout.totalEnergyBurned {
                    data["totalEnergyBurned"] = totalEnergy.doubleValue(for: .kilocalorie())
                    data["totalEnergyBurnedUnit"] = "kcal"
                }
                if let totalDistance = workout.totalDistance {
                     // Use appropriate unit based on workout type or preference
                    data["totalDistance"] = totalDistance.doubleValue(for: .meter())
                    data["totalDistanceUnit"] = "m"
                }
                // Add metadata if needed
                // data["metadata"] = workout.metadata

                return data
            }

            // 6. Serialize to JSON and send result
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: workoutData, options: [])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonString)
                    self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                } else {
                    self.sendError(message: "Failed to encode workout data to JSON string", command: command)
                }
            } catch {
                self.sendError(message: "Failed to serialize workout data: \(error.localizedDescription)", command: command)
            }
        }

        // 7. Execute the query
        healthStore.execute(query)
    }

    // Helper function to send errors
    private func sendError(message: String, command: CDVInvokedUrlCommand) {
        print("Error: \(message)")
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: message)
        // Ensure the callback is on the main thread
         DispatchQueue.main.async {
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
         }
    }
    
}
extension HKWorkoutActivityType {

    /// A human-readable name for the workout activity type.
    var name: String {
        switch self {
        case .americanFootball: return "American Football"
        case .archery: return "Archery"
        case .australianFootball: return "Australian Football"
        case .badminton: return "Badminton"
        case .baseball: return "Baseball"
        case .basketball: return "Basketball"
        case .bowling: return "Bowling"
        case .boxing: return "Boxing"
        case .climbing: return "Climbing"
        case .cricket: return "Cricket"
        case .crossTraining: return "Cross Training"
        case .curling: return "Curling"
        case .cycling: return "Cycling"
        case .dance: return "Dance"
        case .elliptical: return "Elliptical"
        case .equestrianSports: return "Equestrian Sports"
        case .fencing: return "Fencing"
        case .fishing: return "Fishing"
        case .functionalStrengthTraining: return "Functional Strength Training"
        case .golf: return "Golf"
        case .gymnastics: return "Gymnastics"
        case .handball: return "Handball"
        case .hiking: return "Hiking"
        case .hockey: return "Hockey"
        case .hunting: return "Hunting"
        case .lacrosse: return "Lacrosse"
        case .martialArts: return "Martial Arts"
        case .mindAndBody: return "Mind and Body"
        case .mixedMetabolicCardioTraining: return "Mixed Metabolic Cardio Training" // Deprecated
        case .paddleSports: return "Paddle Sports"
        case .play: return "Play"
        case .preparationAndRecovery: return "Preparation and Recovery"
        case .racquetball: return "Racquetball"
        case .rowing: return "Rowing"
        case .rugby: return "Rugby"
        case .running: return "Running"
        case .sailing: return "Sailing"
        case .skatingSports: return "Skating Sports"
        case .snowSports: return "Snow Sports"
        case .soccer: return "Soccer"
        case .softball: return "Softball"
        case .squash: return "Squash"
        case .stairClimbing: return "Stair Climbing"
        case .surfingSports: return "Surfing Sports"
        case .swimming: return "Swimming"
        case .tableTennis: return "Table Tennis"
        case .tennis: return "Tennis"
        case .trackAndField: return "Track and Field"
        case .traditionalStrengthTraining: return "Traditional Strength Training"
        case .volleyball: return "Volleyball"
        case .walking: return "Walking"
        case .waterFitness: return "Water Fitness"
        case .waterPolo: return "Water Polo"
        case .waterSports: return "Water Sports"
        case .wrestling: return "Wrestling"
        case .yoga: return "Yoga"

        // Cases introduced in later iOS versions
        case .barre: return "Barre"
        case .coreTraining: return "Core Training"
        case .crossCountrySkiing: return "Cross Country Skiing"
        case .downhillSkiing: return "Downhill Skiing"
        case .flexibility: return "Flexibility"
        case .highIntensityIntervalTraining: return "High Intensity Interval Training"
        case .jumpRope: return "Jump Rope"
        case .kickboxing: return "Kickboxing"
        case .pilates: return "Pilates"
        case .snowboarding: return "Snowboarding"
        case .stairs: return "Stairs"
        case .stepTraining: return "Step Training"
        case .wheelchairWalkPace: return "Wheelchair Walk Pace"
        case .wheelchairRunPace: return "Wheelchair Run Pace"
        case .taiChi: return "Tai Chi"
        case .mixedCardio: return "Mixed Cardio"
        case .handCycling: return "Hand Cycling"
        case .discSports: return "Disc Sports"
        case .fitnessGaming: return "Fitness Gaming"
        case .cooldown: return "Cooldown"
        case .warmUp: return "Warm Up"
        case .rollerSports: return "Roller Sports"
        case .indoorCycling: return "Indoor Cycling"
        case .indoorRunning: return "Indoor Running"
        case .indoorWalking: return "Indoor Walking"
        case .stairSledding: return "Stair Sledding"
        case .wheelchair: return "Wheelchair"
        case .swimBikeRun: return "Swim Bike Run" // Multisport
        case .transition: return "Transition" // Multisport transition
        case .underwaterDiving: return "Underwater Diving"
        case .other: return "Other"

        // Handle potential new cases or unknown values gracefully
        @unknown default:
            // This will catch any new cases added in future iOS versions
            // that haven't been explicitly added to this switch yet.
            // You can return a generic name or the raw value for debugging.
            return "Unknown Activity Type (\(self.rawValue))"
        }
    }
}
