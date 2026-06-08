//
//  FLEXTabsViewController.m
//
//  Copyright (c) Flipboard (2014-2016); FLEX Team (2020-2026).
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice, this
//    list of conditions and the following disclaimer in the documentation and/or
//    other materials provided with the distribution.
//
//  * Neither the name of Flipboard nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
//  * You must NOT include this project in an application to be submitted
//    to the App Store™, as this project uses too many private APIs.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "FLEXTabsViewController.h"
#import "FLEXNavigationController.h"
#import "FLEXTabList.h"
#import "FLEXBookmarkManager.h"
#import "FLEXTableView.h"
#import "FLEXUtility.h"
#import "FLEXColor.h"
#import "UIBarButtonItem+FLEX.h"
#import "FLEXExplorerViewController.h"
#import "FLEXGlobalsViewController.h"
#import "FLEXObjectExplorerFactory.h"
#import "FLEXRuntimeUtility.h"

typedef NS_ENUM(NSUInteger, FLEXSwitcherMode) {
    FLEXSwitcherModeTabs = 0,
    FLEXSwitcherModeBookmarks = 1,
};

@interface FLEXTabsViewController ()
@property (nonatomic, copy) NSArray<UINavigationController *> *openTabs;
@property (nonatomic, copy) NSArray<UIImage *> *tabSnapshots;
@property (nonatomic) NSInteger activeIndex;
@property (nonatomic) BOOL presentNewActiveTabOnDismiss;

@property (nonatomic, copy) NSArray *bookmarks;
@property (nonatomic) FLEXSwitcherMode mode;
@property (nonatomic) UISegmentedControl *modeControl;

@property (nonatomic, readonly) FLEXExplorerViewController *corePresenter;
@end

@implementation FLEXTabsViewController

#pragma mark - Initialization

- (id)init {
    return [self initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.hidesBarsOnSwipe = NO;
    self.tableView.allowsMultipleSelectionDuringEditing = YES;

    self.modeControl = [[UISegmentedControl alloc] initWithItems:@[@"Tabs", @"Bookmarks"]];
    self.modeControl.selectedSegmentIndex = FLEXSwitcherModeTabs;
    [self.modeControl addTarget:self action:@selector(modeChanged:)
              forControlEvents:UIControlEventValueChanged];

    [self reloadData:NO];
    [self updateTitle];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupDefaultBarItems];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // Update the active tab snapshot after presenting to avoid pre-presentation latency
    dispatch_async(dispatch_get_main_queue(), ^{
        [FLEXTabList.sharedList updateSnapshotForActiveTab];
        [self reloadData:NO];
        [self.tableView reloadData];
    });
}


#pragma mark - Private

- (void)updateTitle {
    self.title = (self.mode == FLEXSwitcherModeTabs) ? @"Tabs" : @"Bookmarks";
}

- (NSInteger)currentListCount {
    return (self.mode == FLEXSwitcherModeTabs) ? self.openTabs.count : self.bookmarks.count;
}

/// @param trackActiveTabDelta whether to check if the active
/// tab changed and needs to be presented upon "Done" dismissal.
/// @return whether the active tab changed or not (if there are any tabs left)
- (BOOL)reloadData:(BOOL)trackActiveTabDelta {
    BOOL activeTabDidChange = NO;
    FLEXTabList *list = FLEXTabList.sharedList;

    if (trackActiveTabDelta) {
        NSInteger oldActiveIndex = self.activeIndex;
        if (oldActiveIndex != list.activeTabIndex && list.activeTabIndex != NSNotFound) {
            self.presentNewActiveTabOnDismiss = YES;
            activeTabDidChange = YES;
        } else if (self.presentNewActiveTabOnDismiss) {
            self.presentNewActiveTabOnDismiss = NO;
        }
    }

    self.openTabs = list.openTabs;
    self.tabSnapshots = list.openTabSnapshots;
    self.activeIndex = list.activeTabIndex;
    self.bookmarks = FLEXBookmarkManager.bookmarks;

    return activeTabDidChange;
}

- (void)reloadActiveTabRowIfChanged:(BOOL)activeTabChanged {
    if (activeTabChanged) {
        NSIndexPath *active = [NSIndexPath indexPathForRow:self.activeIndex inSection:0];
        [self.tableView reloadRowsAtIndexPaths:@[active] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)setupDefaultBarItems {
    self.navigationItem.rightBarButtonItem = FLEXBarButtonItemSystem(Done, self, @selector(dismissAnimated));

    UIBarButtonItem *segment = [[UIBarButtonItem alloc] initWithCustomView:self.modeControl];
    UIBarButtonItem *add = FLEXBarButtonItemSystem(Add, self, @selector(addTabButtonPressed:));
    UIBarButtonItem *edit = FLEXBarButtonItemSystem(Edit, self, @selector(toggleEditing));

    // New Tab only applies to the Tabs segment
    add.enabled = (self.mode == FLEXSwitcherModeTabs);
    // Disable editing if the current list is empty
    edit.enabled = [self currentListCount] > 0;

    self.toolbarItems = @[
        add,
        UIBarButtonItem.flex_flexibleSpace,
        segment,
        UIBarButtonItem.flex_flexibleSpace,
        edit,
    ];
}

- (void)setupEditingBarItems {
    self.navigationItem.rightBarButtonItem = nil;
    NSString *clearTitle = (self.mode == FLEXSwitcherModeTabs) ? @"Close All" : @"Remove All";
    self.toolbarItems = @[
        [UIBarButtonItem flex_itemWithTitle:clearTitle target:self action:@selector(closeAllButtonPressed:)],
        UIBarButtonItem.flex_flexibleSpace,
        // Non-system done item because we change its title dynamically
        [UIBarButtonItem flex_doneStyleitemWithTitle:@"Done" target:self action:@selector(toggleEditing)]
    ];

    self.toolbarItems.firstObject.tintColor = FLEXColor.destructiveColor;
}

- (FLEXExplorerViewController *)corePresenter {
    FLEXExplorerViewController *presenter = (id)self.presentingViewController;
    presenter = (id)presenter.presentingViewController ?: presenter;
    NSAssert(
        [presenter isKindOfClass:[FLEXExplorerViewController class]],
        @"The tabs view controller expects to be presented by the explorer controller"
    );
    return presenter;
}

- (void)openBookmark:(id)selectedObject {
    UIViewController *explorer = [FLEXObjectExplorerFactory explorerViewControllerForObject:selectedObject];
    if ([self.presentingViewController isKindOfClass:[FLEXNavigationController class]]) {
        // Presented on an existing navigation stack: dismiss myself and push there
        UINavigationController *presenter = (id)self.presentingViewController;
        [presenter dismissViewControllerAnimated:YES completion:^{
            [presenter pushViewController:explorer animated:YES];
        }];
    } else {
        // Dismiss myself and present the explorer as a new tab
        UIViewController *presenter = self.corePresenter;
        [presenter dismissViewControllerAnimated:YES completion:^{
            [presenter presentViewController:[FLEXNavigationController
                withRootViewController:explorer
            ] animated:YES completion:nil];
        }];
    }
}


#pragma mark Button Actions

- (void)modeChanged:(UISegmentedControl *)sender {
    if (self.editing) {
        self.editing = NO; // exit editing to avoid cross-mode selection state
    }
    self.mode = sender.selectedSegmentIndex;
    [self reloadData:NO];
    [self.tableView reloadData];
    [self setupDefaultBarItems];
    [self updateTitle];
}

- (void)dismissAnimated {
    if (self.presentNewActiveTabOnDismiss) {
        // The active tab was closed so we need to present the new one
        UIViewController *activeTab = FLEXTabList.sharedList.activeTab;
        FLEXExplorerViewController *presenter = self.corePresenter;
        [presenter dismissViewControllerAnimated:YES completion:^{
            [presenter presentViewController:activeTab animated:YES completion:nil];
        }];
    } else if (self.activeIndex == NSNotFound) {
        // The only tab was closed, so dismiss everything
        [self.corePresenter dismissViewControllerAnimated:YES completion:nil];
    } else {
        // Simple dismiss, only dismiss myself
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)toggleEditing {
    NSArray<NSIndexPath *> *selected = self.tableView.indexPathsForSelectedRows;
    self.editing = !self.editing;

    if (self.isEditing) {
        [self setupEditingBarItems];
    } else {
        [self setupDefaultBarItems];

        NSMutableIndexSet *indexes = [NSMutableIndexSet new];
        for (NSIndexPath *ip in selected) {
            [indexes addIndex:ip.row];
        }

        if (selected.count) {
            if (self.mode == FLEXSwitcherModeTabs) {
                [FLEXTabList.sharedList closeTabsAtIndexes:indexes];
                BOOL activeTabChanged = [self reloadData:YES];
                [self.tableView deleteRowsAtIndexPaths:selected withRowAnimation:UITableViewRowAnimationAutomatic];
                [self reloadActiveTabRowIfChanged:activeTabChanged];
            } else {
                [FLEXBookmarkManager.bookmarks removeObjectsAtIndexes:indexes];
                [self reloadData:NO];
                [self.tableView deleteRowsAtIndexPaths:selected withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
}

- (void)addTabButtonPressed:(UIBarButtonItem *)sender {
    // New tabs always start at the Main Menu; bookmarks are one segment away.
    [self addTabAndDismiss:[FLEXNavigationController
        withRootViewController:[FLEXGlobalsViewController new]
    ]];
}

- (void)addTabAndDismiss:(UINavigationController *)newTab {
    FLEXExplorerViewController *presenter = self.corePresenter;
    [presenter dismissViewControllerAnimated:YES completion:^{
        [presenter presentViewController:newTab animated:YES completion:nil];
    }];
}

- (void)closeAllButtonPressed:(UIBarButtonItem *)sender {
    [FLEXAlert makeSheet:^(FLEXAlert *make) {
        NSInteger count = [self currentListCount];
        NSString *title = (self.mode == FLEXSwitcherModeTabs)
            ? FLEXPluralFormatString(count, @"Close %@ tabs", @"Close %@ tab")
            : FLEXPluralFormatString(count, @"Remove %@ bookmarks", @"Remove %@ bookmark");
        make.button(title).destructiveStyle().handler(^(NSArray<NSString *> *strings) {
            [self closeAll];
            [self toggleEditing];
        });
        make.button(@"Cancel").cancelStyle();
    } showFrom:self source:sender];
}

- (void)closeAll {
    NSInteger rowCount = [self currentListCount];

    if (self.mode == FLEXSwitcherModeTabs) {
        [FLEXTabList.sharedList closeAllTabs];
        [self reloadData:YES];
    } else {
        [FLEXBookmarkManager.bookmarks removeAllObjects];
        [self reloadData:NO];
    }

    NSArray<NSIndexPath *> *allRows = [NSArray flex_forEachUpTo:rowCount map:^id(NSUInteger row) {
        return [NSIndexPath indexPathForRow:row inSection:0];
    }];
    [self.tableView deleteRowsAtIndexPaths:allRows withRowAnimation:UITableViewRowAnimationAutomatic];
}


#pragma mark - Table View Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self currentListCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kFLEXDetailCell forIndexPath:indexPath];

    if (self.mode == FLEXSwitcherModeTabs) {
        UINavigationController *tab = self.openTabs[indexPath.row];
        cell.imageView.image = self.tabSnapshots[indexPath.row];
        cell.textLabel.text = tab.topViewController.title;
        cell.detailTextLabel.text = FLEXPluralString(tab.viewControllers.count, @"pages", @"page");
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        cell.backgroundColor = (indexPath.row == self.activeIndex)
            ? FLEXColor.secondaryBackgroundColor : FLEXColor.primaryBackgroundColor;
    } else {
        id object = self.bookmarks[indexPath.row];
        cell.imageView.image = nil;
        cell.textLabel.text = [FLEXRuntimeUtility safeDescriptionForObject:object];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %p", [object class], object];
        cell.textLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        cell.backgroundColor = FLEXColor.primaryBackgroundColor;
    }

    return cell;
}


#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editing) {
        self.toolbarItems.lastObject.title = (self.mode == FLEXSwitcherModeTabs) ? @"Close Selected" : @"Remove Selected";
        self.toolbarItems.lastObject.tintColor = FLEXColor.destructiveColor;
        return;
    }

    if (self.mode == FLEXSwitcherModeTabs) {
        if (self.activeIndex == indexPath.row && self.corePresenter != self.presentingViewController) {
            [self dismissAnimated];
        } else {
            FLEXTabList.sharedList.activeTabIndex = indexPath.row;
            self.presentNewActiveTabOnDismiss = YES;
            [self dismissAnimated];
        }
    } else {
        [self openBookmark:self.bookmarks[indexPath.row]];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(self.editing);

    if (tableView.indexPathsForSelectedRows.count == 0) {
        self.toolbarItems.lastObject.title = @"Done";
        self.toolbarItems.lastObject.tintColor = self.view.tintColor;
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)table
commitEditingStyle:(UITableViewCellEditingStyle)edit
forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSParameterAssert(edit == UITableViewCellEditingStyleDelete);

    if (self.mode == FLEXSwitcherModeTabs) {
        [FLEXTabList.sharedList closeTab:self.openTabs[indexPath.row]];
        BOOL activeTabChanged = [self reloadData:YES];
        [table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self reloadActiveTabRowIfChanged:activeTabChanged];
    } else {
        [FLEXBookmarkManager.bookmarks removeObjectAtIndex:indexPath.row];
        [self reloadData:NO];
        [table deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
