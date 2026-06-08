#import <XCTest/XCTest.h>
#import "FLEXBookmarkManager.h"

@interface FLEXBookmarkManagerTests : XCTestCase
@end

@implementation FLEXBookmarkManagerTests

- (void)setUp {
    [FLEXBookmarkManager.bookmarks removeAllObjects];
}

- (void)testIsBookmarkedUsesIdentityNotEquality {
    NSString *a = [@"x" mutableCopy];           // distinct instances that are -isEqual:
    NSString *b = [@"x" mutableCopy];
    [FLEXBookmarkManager addBookmark:a];
    XCTAssertTrue([FLEXBookmarkManager isObjectBookmarked:a]);
    XCTAssertFalse([FLEXBookmarkManager isObjectBookmarked:b]); // identity, not equality
}

- (void)testAddIsIdempotent {
    NSObject *o = [NSObject new];
    [FLEXBookmarkManager addBookmark:o];
    [FLEXBookmarkManager addBookmark:o];
    XCTAssertEqual(FLEXBookmarkManager.bookmarks.count, 1);
}

- (void)testRemove {
    NSObject *o = [NSObject new];
    [FLEXBookmarkManager addBookmark:o];
    [FLEXBookmarkManager removeBookmark:o];
    XCTAssertFalse([FLEXBookmarkManager isObjectBookmarked:o]);
    XCTAssertEqual(FLEXBookmarkManager.bookmarks.count, 0);
}

- (void)testNilIsSafe {
    XCTAssertFalse([FLEXBookmarkManager isObjectBookmarked:nil]);
    [FLEXBookmarkManager addBookmark:nil];      // no-op, no crash
    [FLEXBookmarkManager removeBookmark:nil];   // no-op, no crash
    XCTAssertEqual(FLEXBookmarkManager.bookmarks.count, 0);
}

- (void)testRemoveAbsentObjectIsNoOp {
    NSObject *o = [NSObject new];
    [FLEXBookmarkManager removeBookmark:o];
    XCTAssertEqual(FLEXBookmarkManager.bookmarks.count, 0);
}

@end
