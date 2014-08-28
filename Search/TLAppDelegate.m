//
//  TLAppDelegate.m
//  Search
//
//  Created by Tim on 3/27/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import "TLAppDelegate.h"
#import "NSFileManager+DirectoryLocations.h"
#import "WorkAddLTO.h"
#import "WorkAddAIT.h"
#import "WorkAddDMG.h"
#import "WorkSearchAIT.h"
#import "WorkSearchLTO.h"
#import "WorkSearchStorage.h"
#import "WorkSearchLive.h"
#import "WorkCheckStorage.h"
#include "sqlite3.h"

NSOperationQueue* aQueue;

void logString( NSString *log );
void logwindowf( char *formatString, ... );
int dotFolder(const char *);
int is_cap_hex( char digit );
char *colon_convert( char *source );

NSMutableArray *live_strings;
NSMutableArray *storage_strings;
NSMutableArray *ait_strings;
NSMutableArray *lto_strings;
long live_length;
long storage_length;
long ait_length;
long lto_length;

#define TABLE1 
#define TABLE2 
#define BUFFER_SIZE 4096

@implementation TLAppDelegate

@synthesize window;
@synthesize logWindow;
@synthesize infoField;
@synthesize logView;
@synthesize table;
@synthesize searchField;
@synthesize sourcePopup;
@synthesize folderPopup;
@synthesize containsPopup;
@synthesize progress;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

	sqlite3_temp_directory = (char *)[NSTemporaryDirectory() UTF8String];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *df = [fm applicationSupportDirectory];
    NSString *dbPath = [df stringByAppendingPathComponent:@"storage.sqlite"];
    
    sqlite3 *ppDb;
    ppDb = nil;
	int sql_err = 0;
	char * sErrMsg = 0;
	
	sql_err = sqlite3_open( [dbPath UTF8String], &ppDb );
	
	if (sql_err != 0) {
		NSLog( @"Can not open storage.sqlite file" );
		return;
	}
	
	sql_err = sqlite3_exec(ppDb, "CREATE TABLE IF NOT EXISTS PATHS (id INTEGER PRIMARY KEY, source TEXT, path TEXT, name TEXT);", NULL, NULL, &sErrMsg);
	sql_err = sqlite3_exec(ppDb, "CREATE TABLE IF NOT EXISTS DMGS (id INTEGER PRIMARY KEY, name TEXT);", NULL, NULL, &sErrMsg);
    
	if (sql_err != 0) {
		NSLog( @"Cannot execute create table command: %s", sErrMsg );
		return;
	}
    
    sqlite3_close( ppDb );
    
    dbPath = [df stringByAppendingPathComponent:@"lto.sqlite"];
    
	sql_err = sqlite3_open( [dbPath UTF8String], &ppDb );
	
	if (sql_err != 0) {
		NSLog( @"Can not open lto.sqlite file" );
		return;
	}
	
	sql_err = sqlite3_exec(ppDb, "CREATE TABLE IF NOT EXISTS PATHS (id INTEGER PRIMARY KEY, source TEXT, path TEXT, name TEXT);", NULL, NULL, &sErrMsg);
    
	if (sql_err != 0) {
		NSLog( @"Cannot execute create table command: %s", sErrMsg );
		return;
	}
    
    sqlite3_close( ppDb );
    
    dbPath = [df stringByAppendingPathComponent:@"ait.sqlite"];
    
	sql_err = sqlite3_open( [dbPath UTF8String], &ppDb );
	
	if (sql_err != 0) {
		NSLog( @"Can not open ait.sqlite file" );
		return;
	}
	
	sql_err = sqlite3_exec(ppDb, "CREATE TABLE IF NOT EXISTS PATHS (id INTEGER PRIMARY KEY, source TEXT, path TEXT, name TEXT);", NULL, NULL, &sErrMsg);
    
	if (sql_err != 0) {
		NSLog( @"Cannot execute create table command: %s", sErrMsg );
		return;
	}
    
    sqlite3_close( ppDb );
    
    live_strings = [[NSMutableArray alloc] init];
    storage_strings = [[NSMutableArray alloc] init];
    ait_strings = [[NSMutableArray alloc] init];
    lto_strings = [[NSMutableArray alloc] init];
	live_length = 0;
    storage_length = 0;
    ait_length = 0;
    lto_length = 0;
    if( aQueue == nil ) aQueue = [[NSOperationQueue alloc] init];
	[aQueue setMaxConcurrentOperationCount:6];
    [aQueue addObserver:self forKeyPath:@"operations" options:NSKeyValueObservingOptionNew context:self];
	[infoField setStringValue:@"Count: 0"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == self) {
        if (object == aQueue) {
            if ([keyPath isEqualToString:@"operations"]) {
                if ([[aQueue operations] count] == 0) {
                    [progress stopAnimation:self];
                }
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)doClick:(id)sender
{
    NSString *column;
    NSString *likeClause;
    NSString *queryString;
    
    if ([[aQueue operations] count] > 0) {
        [aQueue cancelAllOperations];
//        [aQueue waitUntilAllOperationsAreFinished];
    }
    
    [live_strings removeAllObjects];
    live_length = 0;
    
    [storage_strings removeAllObjects];
    storage_length = 0;
    
    [ait_strings removeAllObjects];
    ait_length = 0;
    
    [lto_strings removeAllObjects];
    lto_length = 0;

	[infoField setStringValue:@"Count: 0"];

    if (![[searchField stringValue] isEqualToString:@""]) {
        if ([[folderPopup titleOfSelectedItem] isEqualToString:@"Folder Name"]) {
            column = @"path";
        }
        else {
            column = @"name";
        }

        if ([[containsPopup titleOfSelectedItem] isEqualToString:@"Contains"]) {
            likeClause = [NSString stringWithFormat:@"%%%@%%", [searchField stringValue]];
        }
        else if ([[containsPopup titleOfSelectedItem] isEqualToString:@"Starts With"]) {
            likeClause = [NSString stringWithFormat:@"%@%%", [searchField stringValue]];
        }
        else {
            likeClause = [NSString stringWithFormat:@"%%%@", [searchField stringValue]];
        }
        
        queryString = [NSString stringWithFormat:@"SELECT source, path, name FROM PATHS WHERE %@ LIKE '%@';", column, likeClause];

        if( aQueue == nil ) aQueue = [[NSOperationQueue alloc] init];
        [aQueue setSuspended:YES];
		
		if ([[sourcePopup titleOfSelectedItem] isEqualToString:@"All"] || [[sourcePopup titleOfSelectedItem] isEqualToString:@"AIT Only"]) {
			WorkSearchAIT *theAIT_Op = [[[WorkSearchAIT alloc] initWithString:queryString] autorelease];
			[aQueue addOperation:theAIT_Op];
		}
		
		if ([[sourcePopup titleOfSelectedItem] isEqualToString:@"All"] || [[sourcePopup titleOfSelectedItem] isEqualToString:@"LTO Only"]) {
			WorkSearchLTO *theLTO_Op = [[[WorkSearchLTO alloc] initWithString:queryString] autorelease];
			[aQueue addOperation:theLTO_Op];
		}
		
		if ([[sourcePopup titleOfSelectedItem] isEqualToString:@"All"] || [[sourcePopup titleOfSelectedItem] isEqualToString:@"Storage Only"]) {
			WorkSearchStorage *theStorage_Op = [[[WorkSearchStorage alloc] initWithString:queryString] autorelease];
			[aQueue addOperation:theStorage_Op];
		}
		
		if ([[sourcePopup titleOfSelectedItem] isEqualToString:@"All"] || [[sourcePopup titleOfSelectedItem] isEqualToString:@"Live Only"]) {
			WorkSearchLive *theLive_Op = [[[WorkSearchLive alloc] initWithString:queryString] autorelease];
			[aQueue addOperation:theLive_Op];
		}
		
        [aQueue setSuspended:NO];
        
        [progress startAnimation:self];
    }

    [table reloadData];
}

- (void)cancelProcesses:(id)sender
{
	[aQueue cancelAllOperations];
}

- (void)addDMGs:(id)sender
{
    NSOpenPanel *op = [NSOpenPanel openPanel];
    [op setCanChooseDirectories:YES];
    [op setCanCreateDirectories:NO];
    
	if( [op runModal] == NSFileHandlingPanelOKButton )
	{
        NSArray *paths = [op filenames];
        NSString *path = [paths lastObject];
        
        if (path != nil) {
            if( aQueue == nil ) aQueue = [[NSOperationQueue alloc] init];
            [aQueue setSuspended:YES];
            WorkAddDMG *theOp = [[[WorkAddDMG alloc] initWithString:path] autorelease];
            [aQueue addOperation:theOp];
            [aQueue setSuspended:NO];
            [progress startAnimation:self];
        }
    }
}

- (void)addLTOFile:(id)sender
{
	NSOpenPanel *op = [NSOpenPanel openPanel];
	
	if( [op runModal] == NSFileHandlingPanelOKButton )
	{
		NSString *filename = [[op filenames] lastObject];
		
		if( aQueue == nil ) aQueue = [[NSOperationQueue alloc] init];
		[aQueue setSuspended:YES];
		WorkAddLTO *theOp = [[[WorkAddLTO alloc] initWithString:filename] autorelease];
		[aQueue addOperation:theOp];
		[aQueue setSuspended:NO];
        [progress startAnimation:self];
    }
}

- (void)addAITFile:(id)sender
{
	NSOpenPanel *op = [NSOpenPanel openPanel];
	
	if( [op runModal] == NSFileHandlingPanelOKButton )
	{
		NSString *filename = [[op filenames] lastObject];
		if( aQueue == nil ) aQueue = [[NSOperationQueue alloc] init];
		[aQueue setSuspended:YES];
		WorkAddAIT *theOp = [[[WorkAddAIT alloc] initWithString:filename] autorelease];
		[aQueue addOperation:theOp];
		[aQueue setSuspended:NO];
        [progress startAnimation:self];
    }
}

- (void)checkDMG:(id)sender
{
	WorkCheckStorage *theOp = [[[WorkCheckStorage alloc] initWithString:@""] autorelease];
	[aQueue addOperation:theOp];
	[progress startAnimation:self];	
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return lto_length + ait_length + storage_length + live_length;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString *result = nil;
    NSInteger row;
    NSArray *array = NULL;
    
    if (rowIndex < ait_length) {
        /* return from ait array */
        row = rowIndex;
        array = ait_strings;
    }
    else if (rowIndex-ait_length < lto_length) {
        /* return from lto array */
        row = rowIndex - ait_length;
        array = lto_strings;
    }
    else if (rowIndex-(ait_length+lto_length) < storage_length ){
        /* return from storage array */
        row = rowIndex - (ait_length + lto_length);
        array = storage_strings;
    }
    else {
        /* return from live array */
        row = rowIndex - (ait_length + lto_length + storage_length);
        array = live_strings;
    }
    
    if ([[aTableColumn identifier] isEqualToString:@"source"]) {
        result = [array objectAtIndex:(row * 3) + 0];
    }
    else if ([[aTableColumn identifier] isEqualToString:@"path"]) {
        result = [array objectAtIndex:(row * 3) + 1];
    }
    else {
        result = [array objectAtIndex:(row * 3) + 2];
    }

	return result;
}

- (void)sendLiveArray:(NSArray *)values
{
    [live_strings addObjectsFromArray:values];
    live_length += [values count] / 3;
	[infoField setStringValue:[NSString stringWithFormat:@"Count: %d", live_length+storage_length+ait_length+lto_length]];
    [table reloadData];
}

- (void)sendStorageArray:(NSArray *)values
{
    [storage_strings addObjectsFromArray:values];
    storage_length += [values count] / 3;
	[infoField setStringValue:[NSString stringWithFormat:@"Count: %d", live_length+storage_length+ait_length+lto_length]];
    [table reloadData];
}

- (void)sendAITArray:(NSArray *)values
{
    [ait_strings addObjectsFromArray:values];
    ait_length += [values count] / 3;
	[infoField setStringValue:[NSString stringWithFormat:@"Count: %d", live_length+storage_length+ait_length+lto_length]];
    [table reloadData];
}

- (void)sendLTOArray:(NSArray *)values
{
    [lto_strings addObjectsFromArray:values];
    lto_length += [values count] / 3;
	[infoField setStringValue:[NSString stringWithFormat:@"Count: %d", live_length+storage_length+ait_length+lto_length]];
    [table reloadData];
}

- (void)logString:(NSString *)log
{
	[[logView textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:log] autorelease]];
	
	if( logView.textStorage.length > 1 )
	{
		NSRange range = NSMakeRange(logView.textStorage.length - 1, 1);
		[logView scrollRangeToVisible:range];
	}
}

@end

void logString( NSString *log )
{
	[[NSApp delegate] performSelectorOnMainThread:@selector(logString:) withObject:log waitUntilDone:NO];
}

void logwindowf( char *formatString, ... )
{
    char result[4096];
    
	va_list args;
    va_start(args, formatString);
    vsnprintf(result, 4096, formatString, args);
    va_end(args);
    
    result[4095] = '\0';
    
	logString( [NSString stringWithCString:result encoding:NSMacOSRomanStringEncoding] );
}

int dotFolder(const char *path)
{
    while( *path )
    {
        if( *path++ == '/' && *path == '.' )
        {
            return 1;
        }
    }
    
    return 0;
}

int is_cap_hex( char digit )
{
	int result = 0;
	
	if( isdigit(digit) )
	{
		result = 1;
	}
	else
	{
		if( digit >= 'A' && digit <= 'F' )
		{
			result = 1;
		}
	}
	
	return result;
}

char *colon_convert( char *source )
{
	char *result = NULL;
    
    
	int colon_count = 0;
	char *temp = source;
	int found = 0;
	
	while( *temp != '\0' )
	{
		if( *(temp++) == ':' ) colon_count++;
	}
	
	if( colon_count > 0 )
	{
		result = malloc( strlen(source) + (colon_count*4) + 1 );
		char *dest = result;
		
		while( *source != '\0' )
		{
			if( *source == ':' )
			{
				if( source[1] != '\0' || source[2] != '\0' )
				{
					if( is_cap_hex(source[1]) && is_cap_hex(source[2]) )
					{
						char in_buffer;
						
						in_buffer = (digittoint(source[1]) << 4) + digittoint(source[2]);
						*(dest++) = in_buffer;
						
						found = 1;
						source += 3;
					}
					else
					{
						*(dest++) = *(source++);
					}
				}
				else
				{
					*(dest++) = *(source++);
				}
			}
			else
			{
				*(dest++) = *(source++);
			}
		}
		
        *dest = '\0';
        
		if( found == 0 )
		{
			free( result );
			result = strdup(source);
		}
	}
	else {
		result = strdup(source);
	}

	
	return result;	
}
