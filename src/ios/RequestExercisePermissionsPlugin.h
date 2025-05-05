#import <Cordova/CDVPlugin.h>
#import <HealthKit/HealthKit.h>

@interface RequestExercisePermissionsPlugin : CDVPlugin

@property (nonatomic, strong) HKHealthStore *healthStore;

- (void)requestPermissions:(CDVInvokedUrlCommand*)command;
- (void)getExerciseData:(CDVInvokedUrlCommand*)command;

@end
