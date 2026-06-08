#import <XCTest/XCTest.h>
#import "FLEXNotificationRecorder.h"
#import "FLEXNotificationRegistration.h"

@interface FLEXNotificationRecorderTests : XCTestCase
@end

@implementation FLEXNotificationRecorderTests {
    FLEXNotificationRecorder *_recorder;
    NSObject *_observerA;
    NSObject *_observerB;
}

- (void)setUp {
    _recorder = [FLEXNotificationRecorder new]; // fresh instance, not the singleton
    _observerA = [NSObject new];
    _observerB = [NSObject new];
}

- (FLEXNotificationRegistration *)regFor:(id)observer name:(NSString *)name object:(id)object {
    return [FLEXNotificationRegistration registrationWithObserver:observer
        selectorString:@"x" name:name object:object returnAddresses:@[]];
}

- (void)testAddAndSnapshot {
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:nil]];
    [_recorder addRegistration:[self regFor:_observerB name:@"N2" object:nil]];
    XCTAssertEqual(_recorder.registrations.count, 2); // serial queue guarantees ordering
}

- (void)testRemoveAllForObserver {
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:nil]];
    [_recorder addRegistration:[self regFor:_observerA name:@"N2" object:nil]];
    [_recorder addRegistration:[self regFor:_observerB name:@"N3" object:nil]];
    [_recorder removeAllRegistrationsForObserverPointer:(uintptr_t)_observerA];
    XCTAssertEqual(_recorder.registrations.count, 1);
    XCTAssertEqual(_recorder.registrations.firstObject.observerPointer, (uintptr_t)_observerB);
}

- (void)testRemoveByNameMatchesOnlyThatName {
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:nil]];
    [_recorder addRegistration:[self regFor:_observerA name:@"N2" object:nil]];
    [_recorder removeRegistrationsForObserverPointer:(uintptr_t)_observerA name:@"N1" objectPointer:0];
    XCTAssertEqual(_recorder.registrations.count, 1);
    XCTAssertEqualObjects(_recorder.registrations.firstObject.notificationName, @"N2");
}

- (void)testClear {
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:nil]];
    [_recorder clear];
    XCTAssertEqual(_recorder.registrations.count, 0);
}

- (void)testRemoveByObjectPointerMatchesOnlyThatObject {
    NSObject *objX = [NSObject new];
    NSObject *objY = [NSObject new];
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:objX]];
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:objY]];
    [_recorder removeRegistrationsForObserverPointer:(uintptr_t)_observerA
        name:nil objectPointer:(uintptr_t)objX];
    XCTAssertEqual(_recorder.registrations.count, 1);
    XCTAssertEqual(_recorder.registrations.firstObject.observedObjectPointer, (uintptr_t)objY);
}

- (void)testRemoveWithNilNameRemovesAllForObserver {
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:nil]];
    [_recorder addRegistration:[self regFor:_observerA name:@"N2" object:nil]];
    [_recorder removeRegistrationsForObserverPointer:(uintptr_t)_observerA name:nil objectPointer:0];
    XCTAssertEqual(_recorder.registrations.count, 0);
}

- (void)testUpdateNotificationPostedOnMain {
    XCTestExpectation *exp = [self expectationWithDescription:@"update notification"];
    id token = [NSNotificationCenter.defaultCenter
        addObserverForName:kFLEXNotificationRecorderUpdatedNotification
                    object:_recorder queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *n) {
                    XCTAssertTrue(NSThread.isMainThread);
                    [exp fulfill];
                }];
    [_recorder addRegistration:[self regFor:_observerA name:@"N1" object:nil]];
    [self waitForExpectations:@[exp] timeout:1.0];
    [NSNotificationCenter.defaultCenter removeObserver:token];
}

@end
