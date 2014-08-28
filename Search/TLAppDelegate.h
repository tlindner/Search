//
//  TLAppDelegate.h
//  Search
//
//  Created by Tim on 3/27/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TLAppDelegate : NSObject {
    NSWindow *window;
	NSTableView *table;
	NSTextField *infoField;
	NSSearchField *searchField;
	NSPopUpButton *sourcePopup;
	NSPopUpButton *folderPopup;
	NSPopUpButton *containsPopup;
    NSProgressIndicator *progress;
    
	NSWindow *logWindow;
	NSTextView *logView;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSWindow *logWindow;
@property (assign) IBOutlet NSTextField *infoField;
@property (assign) IBOutlet NSTextView *logView;
@property (assign) IBOutlet NSTableView *table;
@property (assign) IBOutlet NSSearchField *searchField;
@property (assign) IBOutlet NSPopUpButton *sourcePopup;
@property (assign) IBOutlet NSPopUpButton *folderPopup;
@property (assign) IBOutlet NSPopUpButton *containsPopup;
@property (assign) IBOutlet NSProgressIndicator *progress;

- (void)doClick:(id)sender;
- (void)addDMGs:(id)sender;
- (void)addLTOFile:(id)sender;
- (void)addAITFile:(id)sender;
- (void)checkDMG:(id)sender;
- (void)cancelProcesses:(id)sender;

- (void)sendLiveArray:(NSArray *)values;
- (void)sendStorageArray:(NSArray *)values;
- (void)sendAITArray:(NSArray *)values;
- (void)sendLTOArray:(NSArray *)values;

- (void)logString:(NSString *)log;

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;

@end
