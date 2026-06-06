#import <XCTest/XCTest.h>
#import "FLEXNotificationMonitor.h"
#import "FLEXNotificationRecorder.h"
#import "FLEXNotificationRegistration.h"

@interface FLEXNotificationMonitorTests : XCTestCase
@end

@implementation FLEXNotificationMonitorTests {
    BOOL _wasEnabled;
}

- (void)setUp {
    _wasEnabled = FLEXNotificationMonitor.enabled;
    FLEXNotificationMonitor.enabled = YES;   // installs swizzles once
    [FLEXNotificationMonitor installIfEnabled];
    [FLEXNotificationRecorder.sharedRecorder clear];
}

- (void)tearDown {
    FLEXNotificationMonitor.enabled = _wasEnabled;
}

- (FLEXNotificationRegistration *)findRegForName:(NSString *)name {
    for (FLEXNotificationRegistration *r in FLEXNotificationRecorder.sharedRecorder.registrations) {
        if ([r.notificationName isEqualToString:name]) return r;
    }
    return nil;
}

- (void)testSelectorObserverIsRecorded {
    NSNotificationCenter *ctr = [NSNotificationCenter new];
    NSObject *observer = [NSObject new];
    NSString *name = @"FLEXTest.selector";
    [ctr addObserver:observer selector:@selector(description) name:name object:nil];

    FLEXNotificationRegistration *reg = [self findRegForName:name];
    XCTAssertNotNil(reg);
    XCTAssertEqual(reg.observerPointer, (uintptr_t)observer);
    XCTAssertEqualObjects(reg.selectorString, @"description");
    [ctr removeObserver:observer];
}

- (void)testRemoveObserverDropsRecord {
    NSNotificationCenter *ctr = [NSNotificationCenter new];
    NSObject *observer = [NSObject new];
    NSString *name = @"FLEXTest.remove";
    [ctr addObserver:observer selector:@selector(description) name:name object:nil];
    XCTAssertNotNil([self findRegForName:name]);
    [ctr removeObserver:observer];
    XCTAssertNil([self findRegForName:name]);
}

- (void)testBlockObserverRecordedExactlyOnce {
    NSNotificationCenter *ctr = [NSNotificationCenter new];
    NSString *name = @"FLEXTest.block";
    id token = [ctr addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *n) {}];

    NSUInteger count = 0;
    FLEXNotificationRegistration *found = nil;
    for (FLEXNotificationRegistration *r in FLEXNotificationRecorder.sharedRecorder.registrations) {
        if ([r.notificationName isEqualToString:name]) { count++; found = r; }
    }
    XCTAssertEqual(count, 1, @"block registration should record exactly one entry");
    XCTAssertEqualObjects(found.selectorString, @"(block)");
    [ctr removeObserver:token];
}

- (void)testDisabledDoesNotRecord {
    FLEXNotificationMonitor.enabled = NO;
    [FLEXNotificationRecorder.sharedRecorder clear];
    NSNotificationCenter *ctr = [NSNotificationCenter new];
    NSObject *observer = [NSObject new];
    NSString *name = @"FLEXTest.disabled";
    [ctr addObserver:observer selector:@selector(description) name:name object:nil];
    XCTAssertNil([self findRegForName:name]);
    [ctr removeObserver:observer];
}

@end
