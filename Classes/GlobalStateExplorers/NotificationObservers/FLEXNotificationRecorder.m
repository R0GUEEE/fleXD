#import "FLEXNotificationRecorder.h"
#import "FLEXNotificationRegistration.h"

NSString *const kFLEXNotificationRecorderUpdatedNotification = @"kFLEXNotificationRecorderUpdatedNotification";

#define FLEXSync(queue, expr) ({ \
    __block id __ret = nil; \
    dispatch_sync(queue, ^{ __ret = (expr); }); \
    __ret; \
})

@interface FLEXNotificationRecorder ()
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) NSMutableArray<FLEXNotificationRegistration *> *mutableRegistrations;
@end

@implementation FLEXNotificationRecorder

+ (instancetype)sharedRecorder {
    static FLEXNotificationRecorder *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [self new]; });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("com.flex.FLEXNotificationRecorder", DISPATCH_QUEUE_SERIAL);
        _mutableRegistrations = [NSMutableArray array];
    }
    return self;
}

// Must NOT be called from within self.queue — the dispatch_sync would deadlock.
- (NSArray<FLEXNotificationRegistration *> *)registrations {
    return FLEXSync(self.queue, self.mutableRegistrations.copy);
}

- (void)addRegistration:(FLEXNotificationRegistration *)registration {
    dispatch_async(self.queue, ^{
        [self.mutableRegistrations addObject:registration];
        [self postUpdate];
    });
}

- (void)removeAllRegistrationsForObserverPointer:(uintptr_t)observerPointer {
    dispatch_async(self.queue, ^{
        NSIndexSet *idx = [self.mutableRegistrations indexesOfObjectsPassingTest:
            ^BOOL(FLEXNotificationRegistration *r, NSUInteger i, BOOL *stop) {
                return r.observerPointer == observerPointer;
            }];
        if (idx.count) {
            [self.mutableRegistrations removeObjectsAtIndexes:idx];
            [self postUpdate];
        }
    });
}

- (void)removeRegistrationsForObserverPointer:(uintptr_t)observerPointer
                                         name:(NSString *)name
                                objectPointer:(uintptr_t)objectPointer {
    dispatch_async(self.queue, ^{
        NSIndexSet *idx = [self.mutableRegistrations indexesOfObjectsPassingTest:
            ^BOOL(FLEXNotificationRegistration *r, NSUInteger i, BOOL *stop) {
                if (r.observerPointer != observerPointer) return NO;
                if (name && ![r.notificationName isEqualToString:name]) return NO;
                if (objectPointer && r.observedObjectPointer != objectPointer) return NO;
                return YES;
            }];
        if (idx.count) {
            [self.mutableRegistrations removeObjectsAtIndexes:idx];
            [self postUpdate];
        }
    });
}

- (void)clear {
    dispatch_async(self.queue, ^{
        if (!self.mutableRegistrations.count) return;
        [self.mutableRegistrations removeAllObjects];
        [self postUpdate];
    });
}

// Called from within self.queue; dispatches the notification to the main thread.
- (void)postUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter
            postNotificationName:kFLEXNotificationRecorderUpdatedNotification object:self];
    });
}

@end
