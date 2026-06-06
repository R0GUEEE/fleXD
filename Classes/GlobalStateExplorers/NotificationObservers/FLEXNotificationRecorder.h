#import <Foundation/Foundation.h>

@class FLEXNotificationRegistration;

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main thread whenever the set of registrations changes.
extern NSString *const kFLEXNotificationRecorderUpdatedNotification;

/// Thread-safe store of observer registrations (serial-queue backed,
/// mirroring FLEXNetworkRecorder).
@interface FLEXNotificationRecorder : NSObject

@property (class, nonatomic, readonly) FLEXNotificationRecorder *sharedRecorder;

/// A snapshot of current registrations, in registration order.
@property (nonatomic, readonly) NSArray<FLEXNotificationRegistration *> *registrations;

- (void)addRegistration:(FLEXNotificationRegistration *)registration;

/// Mirrors -[NSNotificationCenter removeObserver:] — removes every
/// registration for the given observer pointer.
- (void)removeAllRegistrationsForObserverPointer:(uintptr_t)observerPointer;

/// Mirrors -[NSNotificationCenter removeObserver:name:object:] — a nil name
/// (pass nil) or zero objectPointer matches any.
- (void)removeRegistrationsForObserverPointer:(uintptr_t)observerPointer
                                         name:(nullable NSString *)name
                                objectPointer:(uintptr_t)objectPointer;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
