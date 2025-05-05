#import "RequestExercisePermissionsPlugin.h"

@implementation RequestExercisePermissionsPlugin

@synthesize healthStore;

- (void)pluginInitialize {
    [super pluginInitialize];
    self.healthStore = [[HKHealthStore alloc] init];

    if (![HKHealthStore isHealthDataAvailable]) {
        NSLog(@"Warning: HealthKit is not available on this device.");
    } else {
        NSLog(@"Info: HealthKit is available.");
    }
}

- (void)requestPermissions:(CDVInvokedUrlCommand*)command {
    if (![HKHealthStore isHealthDataAvailable]) {
        NSLog(@"Error: Permission request failed: HealthKit not available.");
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"HealthKit not available"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    // Define base types
    NSMutableSet *readTypes = [NSMutableSet setWithObjects:
                               [HKObjectType workoutType],
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned],
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned],
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate],
                               // Add all relevant distance types we might query later
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning],
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCycling],
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceSwimming],
                               [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWheelchair],
                               nil];

    // Add distance types available in newer OS versions conditionally
    if (@available(iOS 18.0, *)) {
        // Note: Ensure this identifier truly requires iOS 18+ based on latest Apple docs if issues arise
        [readTypes addObject:[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceRowing]];
        [readTypes addObject:[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistancePaddleSports]];
        [readTypes addObject:[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceSkatingSports]];

        HKQuantityType *crossCountrySkiingType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCrossCountrySkiing];
        if (crossCountrySkiingType) {
            [readTypes addObject:crossCountrySkiingType];
        }
    }
    if (@available(iOS 11.2, *)) {
         HKQuantityType *downhillSnowSportsType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceDownhillSnowSports];
         if (downhillSnowSportsType) {
             [readTypes addObject:downhillSnowSportsType];
         }
    }
    // Add other distance types here if needed

    NSMutableArray *typeIdentifiers = [NSMutableArray array];
    for (HKObjectType *type in readTypes) {
        [typeIdentifiers addObject:type.identifier];
    }
    NSLog(@"Debug: Requesting authorization for types: %@", [typeIdentifiers componentsJoinedByString:@", "]);

    __weak RequestExercisePermissionsPlugin *weakSelf = self;
    [self.healthStore requestAuthorizationToShareTypes:nil readTypes:readTypes completion:^(BOOL success, NSError * _Nullable error) {
        RequestExercisePermissionsPlugin *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        CDVPluginResult* pluginResult = nil;
        if (error) {
            NSLog(@"Error: Error requesting HealthKit authorization: %@", error.localizedDescription);
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Authorization error: %@", error.localizedDescription]];
        } else {
            if (success) {
                NSLog(@"Info: HealthKit authorization request process completed successfully (permissions may or may not be granted).");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"Authorization request processed."];
            } else {
                NSLog(@"Warning: HealthKit authorization request process failed without error.");
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Authorization denied or failed"];
            }
        }
        [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getExerciseData:(CDVInvokedUrlCommand*)command {
    NSLog(@"Debug: getExerciseData called");

    if (![HKHealthStore isHealthDataAvailable]) {
        [self sendErrorMessage:@"HealthKit not available" command:command];
        return;
    }

    // Check Authorization Status
    HKObjectType *workoutType = [HKObjectType workoutType];
    HKQuantityType *activeEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    HKQuantityType *basalEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned];
    HKQuantityType *heartRateType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    // Distance status checked dynamically in fetchSamples

    HKAuthorizationStatus workoutStatus = [self.healthStore authorizationStatusForType:workoutType];
    HKAuthorizationStatus activeEnergyStatus = [self.healthStore authorizationStatusForType:activeEnergyType];
    HKAuthorizationStatus basalEnergyStatus = [self.healthStore authorizationStatusForType:basalEnergyType];
    HKAuthorizationStatus heartRateStatus = [self.healthStore authorizationStatusForType:heartRateType];

    NSLog(@"Debug: Auth Status Check (Core):\nWorkout: %ld, ActiveEnergy: %ld, BasalEnergy: %ld, HR: %ld",
          (long)workoutStatus, (long)activeEnergyStatus, (long)basalEnergyStatus, (long)heartRateStatus);

    if (workoutStatus == HKAuthorizationStatusNotDetermined ||
        activeEnergyStatus == HKAuthorizationStatusNotDetermined ||
        // basalEnergyStatus == HKAuthorizationStatusNotDetermined || // Basal might not be granted/needed
        heartRateStatus == HKAuthorizationStatusNotDetermined) {

        NSMutableArray *notDeterminedTypes = [NSMutableArray array];
        if (workoutStatus == HKAuthorizationStatusNotDetermined) { [notDeterminedTypes addObject:@"Workouts"]; }
        if (activeEnergyStatus == HKAuthorizationStatusNotDetermined) { [notDeterminedTypes addObject:@"Active Energy"]; }
        // if (basalEnergyStatus == HKAuthorizationStatusNotDetermined) { [notDeterminedTypes addObject:@"Basal Energy"]; }
        if (heartRateStatus == HKAuthorizationStatusNotDetermined) { [notDeterminedTypes addObject:@"Heart Rate"]; }

        NSString *errorMessage = [NSString stringWithFormat:@"HealthKit authorization status not determined for essential types: %@. Please request permissions first.", [notDeterminedTypes componentsJoinedByString:@", "]];
        [self sendErrorMessage:errorMessage command:command];
        return;
    }

    // Parse Arguments
    NSString *startDateStr = [command.arguments objectAtIndex:0];
    NSString *endDateStr = [command.arguments objectAtIndex:1];

    if (!startDateStr || !endDateStr) {
        [self sendErrorMessage:@"Invalid arguments: Start and end date strings required" command:command];
        return;
    }

    NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
    dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;

    NSDate *startDate = [dateFormatter dateFromString:startDateStr];
    NSDate *endDate = [dateFormatter dateFromString:endDateStr];

    if (!startDate || !endDate) {
        [self sendErrorMessage:@"Invalid date format: Use ISO 8601 format" command:command];
        return;
    }
    NSLog(@"Info: Querying workouts from %@ to %@", startDate, endDate);

    // Prepare Main Workout Query
    NSPredicate *timePredicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionStrictStartDate];
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:NO];

    __weak RequestExercisePermissionsPlugin *weakSelf = self;
    HKSampleQuery *workoutQuery = [[HKSampleQuery alloc] initWithSampleType:workoutType
                                                                   predicate:timePredicate
                                                                       limit:HKObjectQueryNoLimit
                                                                   sortDescriptors:@[sortDescriptor]
                                                             resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable samples, NSError * _Nullable error) {
        RequestExercisePermissionsPlugin *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (error) {
            [strongSelf sendErrorMessage:[NSString stringWithFormat:@"Error querying workouts: %@", error.localizedDescription] command:command];
            return;
        }

        NSArray<HKWorkout *> *workouts = (NSArray<HKWorkout *> *)samples;
        if (!workouts || workouts.count == 0) {
            NSLog(@"Info: No workouts found in the specified date range.");
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"[]"];
            [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }

        NSLog(@"Info: Found %lu workouts. Fetching detailed samples...", (unsigned long)workouts.count);

        // Process Each Workout with Sub-Queries
        __block NSMutableArray *finalResults = [NSMutableArray array];
        dispatch_group_t allWorkoutsGroup = dispatch_group_create();
        // Using a serial queue for appending results to avoid race conditions simply.
        dispatch_queue_t resultsQueue = dispatch_queue_create("com.axians.plugin.resultsQueue", DISPATCH_QUEUE_SERIAL);

        for (HKWorkout *workout in workouts) {
            dispatch_group_enter(allWorkoutsGroup);
            [strongSelf fetchSamplesForWorkout:workout completion:^(NSDictionary *workoutDetailDict) {
                if (workoutDetailDict) {
                    dispatch_async(resultsQueue, ^{ // Append results serially
                        [finalResults addObject:workoutDetailDict];
                        dispatch_group_leave(allWorkoutsGroup);
                    });
                } else {
                     NSLog(@"Warning: Failed to fetch details for workout UUID: %@", workout.UUID.UUIDString);
                     dispatch_group_leave(allWorkoutsGroup); // Leave even if fetching details failed
                }
            }];
        }

        // Wait for all workouts and send final result
        dispatch_group_notify(allWorkoutsGroup, dispatch_get_main_queue(), ^{
            NSLog(@"Info: Finished processing all workouts (%lu). Serializing and sending result.", (unsigned long)finalResults.count);
            // Access finalResults safely after all appends are done by ensuring notify waits
            dispatch_async(resultsQueue, ^{ // Ensure sorting happens after all appends
                // Sort results by start date descending
                NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
                dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
                NSArray *sortedResults = [finalResults sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *dict1, NSDictionary *dict2) {
                    NSString *dateStr1 = dict1[@"startDate"];
                    NSString *dateStr2 = dict2[@"startDate"];
                    NSDate *date1 = [dateFormatter dateFromString:dateStr1];
                    NSDate *date2 = [dateFormatter dateFromString:dateStr2];
                    if (!date1 || !date2) {
                        return NSOrderedSame;
                    }
                    return [date2 compare:date1]; // Descending
                }];

                NSError *jsonError = nil;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:sortedResults options:0 error:&jsonError];

                if (jsonError) {
                    [strongSelf sendErrorMessage:[NSString stringWithFormat:@"Failed to serialize final results: %@", jsonError.localizedDescription] command:command];
                } else {
                    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                    if (jsonString) {
                        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
                        [strongSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                    } else {
                        [strongSelf sendErrorMessage:@"Failed to encode final results to JSON string" command:command];
                    }
                }
            }); // End resultsQueue.async
        }); // End allWorkoutsGroup.notify
    }];
    [self.healthStore executeQuery:workoutQuery];
}

// Helper function to determine appropriate distance type based on workout activity
- (HKQuantityType *)getDistanceTypeForActivityType:(HKWorkoutActivityType)activityType {
    switch (activityType) {
        case HKWorkoutActivityTypeRunning:
        case HKWorkoutActivityTypeWalking:
        case HKWorkoutActivityTypeHiking:
            return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
        case HKWorkoutActivityTypeCycling:
        case HKWorkoutActivityTypeHandCycling:
            return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCycling];
        case HKWorkoutActivityTypeSwimming:
            return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceSwimming];
        case HKWorkoutActivityTypeWheelchairRunPace:
        case HKWorkoutActivityTypeWheelchairWalkPace:
            return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWheelchair];
        case HKWorkoutActivityTypeRowing:
            if (@available(iOS 18.0, *)) {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceRowing];
            } else {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
            }
        case HKWorkoutActivityTypePaddleSports:
            if (@available(iOS 18.0, *)) {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistancePaddleSports];
            } else {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
            }
        case HKWorkoutActivityTypeSkatingSports:
            if (@available(iOS 18.0, *)) {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceSkatingSports];
            } else {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
            }
        case HKWorkoutActivityTypeCrossCountrySkiing:
            if (@available(iOS 18.0, *)) {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCrossCountrySkiing];
            } else {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
            }
        case HKWorkoutActivityTypeDownhillSkiing:
        case HKWorkoutActivityTypeSnowboarding:
        case HKWorkoutActivityTypeSnowSports:
            if (@available(iOS 11.2, *)) {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceDownhillSnowSports];
            } else {
                return [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
            }
        default:
            // Return nil if no specific distance type is typically associated
            NSLog(@"Debug: No distance type mapping for activity: %lu", (unsigned long)activityType);
            return nil;
    }
}

// Helper function to fetch samples for a given workout
- (void)fetchSamplesForWorkout:(HKWorkout *)workout completion:(void (^)(NSDictionary *))completion {
    dispatch_group_t sampleGroup = dispatch_group_create();
    __block NSNumber *activeCaloriesSum = nil;
    __block NSNumber *basalCaloriesSum = nil;
    __block NSNumber *distanceSum = nil;
    __block NSMutableArray *heartRateValues = nil;

    NSPredicate *workoutPredicate = [HKQuery predicateForSamplesWithStartDate:workout.startDate endDate:workout.endDate options:HKQueryOptionStrictStartDate];

    // Define Types and Units
    HKQuantityType *activeEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
    HKQuantityType *basalEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBasalEnergyBurned];
    HKQuantityType *heartRateType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
    HKUnit *energyUnit = [HKUnit kilocalorieUnit];
    HKUnit *distanceUnit = [HKUnit meterUnit];
    HKUnit *hrUnit = [[HKUnit countUnit] unitDividedByUnit:[HKUnit minuteUnit]];

    // --- Query Active Calories Sum ---
    dispatch_group_enter(sampleGroup);
    HKStatisticsQuery *activeCaloriesQuery = [[HKStatisticsQuery alloc] initWithQuantityType:activeEnergyType
                                                                     quantitySamplePredicate:workoutPredicate
                                                                                     options:HKStatisticsOptionCumulativeSum
                                                                           completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error querying active calories: %@", error.localizedDescription);
        } else {
            activeCaloriesSum = @([result.sumQuantity doubleValueForUnit:energyUnit]);
            NSLog(@"Debug: Active calories sum for workout %@: %@", workout.UUID.UUIDString, activeCaloriesSum ?: @(-1));
        }
        dispatch_group_leave(sampleGroup);
    }];
    [self.healthStore executeQuery:activeCaloriesQuery];

    // --- Query Basal Calories Sum ---
    dispatch_group_enter(sampleGroup);
    HKStatisticsQuery *basalCaloriesQuery = [[HKStatisticsQuery alloc] initWithQuantityType:basalEnergyType
                                                                    quantitySamplePredicate:workoutPredicate
                                                                                    options:HKStatisticsOptionCumulativeSum
                                                                          completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error querying basal calories: %@", error.localizedDescription);
        } else {
            basalCaloriesSum = @([result.sumQuantity doubleValueForUnit:energyUnit]);
            NSLog(@"Debug: Basal calories sum for workout %@: %@", workout.UUID.UUIDString, basalCaloriesSum ?: @(-1));
        }
        dispatch_group_leave(sampleGroup);
    }];
    [self.healthStore executeQuery:basalCaloriesQuery];

    // --- Query Distance Sum (Dynamically Typed) ---
    HKQuantityType *distanceType = [self getDistanceTypeForActivityType:workout.workoutActivityType];
    if (distanceType) {
        HKAuthorizationStatus distanceStatus = [self.healthStore authorizationStatusForType:distanceType];
        NSLog(@"Debug: Auth status for %@: %ld", distanceType.identifier, (long)distanceStatus);
        // Proceed if permission is granted OR denied (per user request)
        if (distanceStatus == HKAuthorizationStatusSharingAuthorized || distanceStatus == HKAuthorizationStatusSharingDenied) {
            dispatch_group_enter(sampleGroup);
            HKStatisticsQuery *distanceQuery = [[HKStatisticsQuery alloc] initWithQuantityType:distanceType
                                                                       quantitySamplePredicate:workoutPredicate
                                                                                       options:HKStatisticsOptionCumulativeSum
                                                                             completionHandler:^(HKStatisticsQuery * _Nonnull query, HKStatistics * _Nullable result, NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Error querying distance (%@): %@", distanceType.identifier, error.localizedDescription);
                } else {
                    distanceSum = @([result.sumQuantity doubleValueForUnit:distanceUnit]);
                    NSLog(@"Debug: Distance sum (%@) for workout %@: %@", distanceType.identifier, workout.UUID.UUIDString, distanceSum ?: @(-1));
                }
                dispatch_group_leave(sampleGroup);
            }];
            [self.healthStore executeQuery:distanceQuery];
        } else {
            NSLog(@"Warning: Distance type %@ has status .notDetermined, skipping query.", distanceType.identifier);
        }
    } else {
        NSLog(@"Debug: No specific distance type associated with activity type %lu, skipping distance query.", (unsigned long)workout.workoutActivityType);
    }

    // --- Query Heart Rate Samples ---
    dispatch_group_enter(sampleGroup);
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:HKSampleSortIdentifierStartDate ascending:YES];
    HKSampleQuery *hrQuery = [[HKSampleQuery alloc] initWithSampleType:heartRateType
                                                              predicate:workoutPredicate
                                                                  limit:HKObjectQueryNoLimit
                                                        sortDescriptors:@[sortDescriptor]
                                                          resultsHandler:^(HKSampleQuery * _Nonnull query, NSArray<__kindof HKSample *> * _Nullable samples, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error querying heart rates: %@", error.localizedDescription);
        } else {
            heartRateValues = [NSMutableArray array];
            for (HKQuantitySample *sample in samples) {
                [heartRateValues addObject:@([sample.quantity doubleValueForUnit:hrUnit])];
            }
            NSLog(@"Debug: Found %lu heart rate samples for workout %@", (unsigned long)heartRateValues.count, workout.UUID.UUIDString);
        }
        dispatch_group_leave(sampleGroup);
    }];
    [self.healthStore executeQuery:hrQuery];

    // --- Notify when all sample queries are done ---
    dispatch_group_notify(sampleGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Debug: Sample queries finished for workout %@. Formatting output.", workout.UUID.UUIDString);
        NSISO8601DateFormatter *dateFormatter = [[NSISO8601DateFormatter alloc] init];
        dateFormatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        NSString *workoutStartDateStr = [dateFormatter stringFromDate:workout.startDate];
        NSString *workoutEndDateStr = [dateFormatter stringFromDate:workout.endDate];

        // --- Construct Samples Array ---
        NSMutableArray *samplesArray = [NSMutableArray array];
        NSDictionary *activeCaloriesSample = @{
            @"startDate": workoutStartDateStr, @"endDate": workoutEndDateStr, @"block": @1,
            @"values": @[activeCaloriesSum ?: @(0.0)], @"additionalData": @"ACTIVE_CALORIES_BURNED"
        };
        [samplesArray addObject:activeCaloriesSample];
        NSDictionary *heartRateSample = @{
            @"startDate": workoutStartDateStr, @"endDate": workoutEndDateStr, @"block": @1,
            @"values": heartRateValues ?: @[], @"additionalData": @"HEART_RATE"
        };
        [samplesArray addObject:heartRateSample];

        // --- Construct Main Workout Dictionary ---
        double totalCalculatedEnergy = (activeCaloriesSum.doubleValue ?: 0.0) + (basalCaloriesSum.doubleValue ?: 0.0);
        double totalCalculatedDistance = distanceSum.doubleValue ?: 0.0;

        NSDictionary *workoutDict = @{
            @"startDate": workoutStartDateStr,
            @"endDate": workoutEndDateStr,
            @"duration": @(workout.duration),
            @"activity": [self nameForWorkoutActivityType:workout.workoutActivityType], // Use helper for activity name
            @"totalDistance": @(totalCalculatedDistance),
            @"totalEnergyBurned": @(totalCalculatedEnergy),
            @"samples": samplesArray
        };
        completion(workoutDict);
    });
}

// Helper function to get human-readable name for workout activity type
- (NSString *)nameForWorkoutActivityType:(HKWorkoutActivityType)activityType {
    switch (activityType) {
        case HKWorkoutActivityTypeAmericanFootball: return @"American Football";
        case HKWorkoutActivityTypeArchery: return @"Archery";
        case HKWorkoutActivityTypeAustralianFootball: return @"Australian Football";
        case HKWorkoutActivityTypeBadminton: return @"Badminton";
        case HKWorkoutActivityTypeBaseball: return @"Baseball";
        case HKWorkoutActivityTypeBasketball: return @"Basketball";
        case HKWorkoutActivityTypeBowling: return @"Bowling";
        case HKWorkoutActivityTypeBoxing: return @"Boxing";
        case HKWorkoutActivityTypeClimbing: return @"Climbing";
        case HKWorkoutActivityTypeCricket: return @"Cricket";
        case HKWorkoutActivityTypeCrossTraining: return @"Cross Training";
        case HKWorkoutActivityTypeCurling: return @"Curling";
        case HKWorkoutActivityTypeCycling: return @"Cycling";
        case HKWorkoutActivityTypeDance: return @"Dance";
        case HKWorkoutActivityTypeElliptical: return @"Elliptical";
        case HKWorkoutActivityTypeEquestrianSports: return @"Equestrian Sports";
        case HKWorkoutActivityTypeFencing: return @"Fencing";
        case HKWorkoutActivityTypeFishing: return @"Fishing";
        case HKWorkoutActivityTypeFunctionalStrengthTraining: return @"Functional Strength Training";
        case HKWorkoutActivityTypeGolf: return @"Golf";
        case HKWorkoutActivityTypeGymnastics: return @"Gymnastics";
        case HKWorkoutActivityTypeHandball: return @"Handball";
        case HKWorkoutActivityTypeHiking: return @"Hiking";
        case HKWorkoutActivityTypeHockey: return @"Hockey";
        case HKWorkoutActivityTypeHunting: return @"Hunting";
        case HKWorkoutActivityTypeLacrosse: return @"Lacrosse";
        case HKWorkoutActivityTypeMartialArts: return @"Martial Arts";
        case HKWorkoutActivityTypeMindAndBody: return @"Mind and Body";
        case HKWorkoutActivityTypeMixedMetabolicCardioTraining: return @"Mixed Metabolic Cardio Training";
        case HKWorkoutActivityTypePaddleSports: return @"Paddle Sports";
        case HKWorkoutActivityTypePlay: return @"Play";
        case HKWorkoutActivityTypePreparationAndRecovery: return @"Preparation and Recovery";
        case HKWorkoutActivityTypeRacquetball: return @"Racquetball";
        case HKWorkoutActivityTypeRowing: return @"Rowing";
        case HKWorkoutActivityTypeRugby: return @"Rugby";
        case HKWorkoutActivityTypeRunning: return @"Running";
        case HKWorkoutActivityTypeSailing: return @"Sailing";
        case HKWorkoutActivityTypeSkatingSports: return @"Skating Sports";
        case HKWorkoutActivityTypeSnowSports: return @"Snow Sports";
        case HKWorkoutActivityTypeSoccer: return @"Soccer";
        case HKWorkoutActivityTypeSoftball: return @"Softball";
        case HKWorkoutActivityTypeSquash: return @"Squash";
        case HKWorkoutActivityTypeStairClimbing: return @"Stair Climbing";
        case HKWorkoutActivityTypeSurfingSports: return @"Surfing Sports";
        case HKWorkoutActivityTypeSwimming: return @"Swimming";
        case HKWorkoutActivityTypeTableTennis: return @"Table Tennis";
        case HKWorkoutActivityTypeTennis: return @"Tennis";
        case HKWorkoutActivityTypeTrackAndField: return @"Track and Field";
        case HKWorkoutActivityTypeTraditionalStrengthTraining: return @"Traditional Strength Training";
        case HKWorkoutActivityTypeVolleyball: return @"Volleyball";
        case HKWorkoutActivityTypeWalking: return @"Walking";
        case HKWorkoutActivityTypeWaterFitness: return @"Water Fitness";
        case HKWorkoutActivityTypeWaterPolo: return @"Water Polo";
        case HKWorkoutActivityTypeWaterSports: return @"Water Sports";
        case HKWorkoutActivityTypeWrestling: return @"Wrestling";
        case HKWorkoutActivityTypeYoga: return @"Yoga";
        case HKWorkoutActivityTypeBarre: return @"Barre";
        case HKWorkoutActivityTypeCoreTraining: return @"Core Training";
        case HKWorkoutActivityTypeCrossCountrySkiing: return @"Cross Country Skiing";
        case HKWorkoutActivityTypeDownhillSkiing: return @"Downhill Skiing";
        case HKWorkoutActivityTypeFlexibility: return @"Flexibility";
        case HKWorkoutActivityTypeHighIntensityIntervalTraining: return @"High Intensity Interval Training";
        case HKWorkoutActivityTypeJumpRope: return @"Jump Rope";
        case HKWorkoutActivityTypeKickboxing: return @"Kickboxing";
        case HKWorkoutActivityTypePilates: return @"Pilates";
        case HKWorkoutActivityTypeSnowboarding: return @"Snowboarding";
        case HKWorkoutActivityTypeStairs: return @"Stairs";
        case HKWorkoutActivityTypeStepTraining: return @"Step Training";
        case HKWorkoutActivityTypeWheelchairWalkPace: return @"Wheelchair Walk Pace";
        case HKWorkoutActivityTypeWheelchairRunPace: return @"Wheelchair Run Pace";
        case HKWorkoutActivityTypeTaiChi: return @"Tai Chi";
        case HKWorkoutActivityTypeMixedCardio: return @"Mixed Cardio";
        case HKWorkoutActivityTypeHandCycling: return @"Hand Cycling";
        case HKWorkoutActivityTypeOther: return @"Other";
        default: return @"Other";
    }
}


// Helper function to send error result back to Cordova
- (void)sendErrorMessage:(NSString *)message command:(CDVInvokedUrlCommand *)command {
    NSLog(@"Error: Plugin Error: %@", message);
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


@end
