#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs swizzles on NSNotificationCenter add/remove methods to feed
/// FLEXNotificationRecorder. Opt-in, gated by NSUserDefaults (mirrors
/// FLEXNetworkObserver). Swizzles install once and remain; recording no-ops
/// while disabled.
@interface FLEXNotificationMonitor : NSObject

@property (class, nonatomic) BOOL enabled;

/// Installs the swizzles if `enabled`. Safe to call repeatedly (dispatch_once).
+ (void)installIfEnabled;

@end

NS_ASSUME_NONNULL_END
