//
//  FLEXToolbarStashMath.h
//  FLEX
//
//  Pure geometry helpers for PiP-style toolbar stashing. Header-only
//  (static inline) so the explorer view controller and the unit tests can
//  both use them without a separate compilation unit.
//

#import <UIKit/UIKit.h>
#import "FLEXExplorerToolbar.h"   // FLEXToolbarStashEdge

/// Normalized initial velocity for one axis of a UISpringTimingParameters:
/// gesture velocity (pt/s) over remaining travel (pt). Returns 0 for a
/// near-zero distance, and clamps the magnitude so a tiny tuck with a fast
/// flick can't produce an explosive spring.
static inline CGFloat FLEXRelativeSpringVelocity(CGFloat velocity, CGFloat distance, CGFloat maxMagnitude) {
    if (fabs(distance) < 0.5) {
        return 0.0;
    }
    CGFloat relative = velocity / distance;
    if (relative >  maxMagnitude) return  maxMagnitude;
    if (relative < -maxMagnitude) return -maxMagnitude;
    return relative;
}

/// Decide which edge a pan release should stash against, PiP-style: project the
/// horizontal flick under a linear decay and stash if the projected center lands
/// within `band` of (or past) an edge. A predominantly-vertical flick never
/// stashes. All geometry is passed explicitly so this is unit-testable with no view.
///
/// @param velocity     release velocity (pt/s); x drives the stash, y is the vertical guard
/// @param centerX      toolbar center X at release
/// @param minX         left edge, e.g. CGRectGetMinX(safeArea)
/// @param maxX         right edge, e.g. CGRectGetMaxX(safeArea)
/// @param band         how close to an edge the projected center must land to stash (pt)
/// @param deceleration projected travel per (pt/s) of velocity: travel = velocity.x * deceleration
static inline FLEXToolbarStashEdge FLEXStashEdgeForRelease(CGPoint velocity,
                                                           CGFloat centerX,
                                                           CGFloat minX,
                                                           CGFloat maxX,
                                                           CGFloat band,
                                                           CGFloat deceleration) {
    if (fabs(velocity.x) < fabs(velocity.y)) {
        return FLEXToolbarStashEdgeNone;
    }
    CGFloat projectedCenterX = centerX + velocity.x * deceleration;
    if (projectedCenterX <= minX + band) {
        return FLEXToolbarStashEdgeLeft;
    }
    if (projectedCenterX >= maxX - band) {
        return FLEXToolbarStashEdgeRight;
    }
    return FLEXToolbarStashEdgeNone;
}
