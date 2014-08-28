//
//  WorkSearchLTO.m
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import "WorkSearchLTO.h"
#import "NSFileManager+DirectoryLocations.h"
#include "sqlite3.h"

extern void logString( NSString *log );
extern void logwindowf( char *formatString, ... );
extern int dotFolder(const char *path);

#define BUFFER_SIZE 4096

@implementation WorkSearchLTO

- (id)init {
    self = [super init];
    if (self) {
        executing = NO;
        finished = NO;
    }
    return self;
}

- (id)initWithString:(NSString *)data {
	if (self = [super init])
		searchQuery = [data retain];
	return self;
}

- (void)dealloc {
	[super dealloc];
}

- (void)start {
	
	// Always check for cancellation before launching the task.
	if ([self isCancelled])
	{
		// Must move the operation to the finished state if it is canceled.
		[self willChangeValueForKey:@"isFinished"];
		finished = YES;
		[self didChangeValueForKey:@"isFinished"];
		return;
	}
	
	// If the operation is not canceled, begin executing the task.
	
	if (searchQuery != nil) {
		[self willChangeValueForKey:@"isExecuting"];
		[NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
		executing = YES;
		[self didChangeValueForKey:@"isExecuting"];
	}
	else {
		[self willChangeValueForKey:@"isFinished"];
		finished = YES;
		[self didChangeValueForKey:@"isFinished"];
		return;
	}
}

-(void)main {
	@try {
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		sqlite3 *ppDb;
		sqlite3_stmt *stmt;
		
		logString( @"Search LTO: Starting work\n" );
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *df = [fm applicationSupportDirectory];
		NSString *databasePath = [df stringByAppendingPathComponent:@"lto.sqlite"];
		
		ppDb = nil;
		int sql_err = 0;
		const char *tail = 0;
        
		sql_err = sqlite3_open( [databasePath UTF8String], &ppDb );
		
		if (sql_err == 0) {

            sql_err = sqlite3_prepare_v2(ppDb, [searchQuery UTF8String], -1, &stmt, &tail);

            if (stmt != NULL) {
                NSMutableArray *array;
                NSUInteger count;
                
                array = [[[NSMutableArray alloc] init] autorelease];
                count = 0;
                while (true) {
                    sql_err = sqlite3_step(stmt);

                    if (sql_err == SQLITE_ROW) {
                        const unsigned char *string;

                        string = sqlite3_column_text(stmt, 0);
                        [array addObject:[NSString stringWithCString:(const char *)string encoding:NSMacOSRomanStringEncoding]];
                        string = sqlite3_column_text(stmt, 1);
                        [array addObject:[NSString stringWithCString:(const char *)string encoding:NSMacOSRomanStringEncoding]];
                        string = sqlite3_column_text(stmt, 2);
                        [array addObject:[NSString stringWithCString:(const char *)string encoding:NSMacOSRomanStringEncoding]];
                        count++;
                    }
                    else {
                        break;
                    }
                    
                    if (count == 50) {
                        if ([self isCancelled]) {
                            [array removeAllObjects];
                            count = 0;
                            break;
                        }
                        else {
                            [[NSApp delegate] performSelectorOnMainThread:@selector(sendLTOArray:) withObject:array waitUntilDone:YES];
                            [array removeAllObjects];
                            count = 0;
                        }
                    }
                }

                if (count > 0) {
                    [[NSApp delegate] performSelectorOnMainThread:@selector(sendLTOArray:) withObject:array waitUntilDone:YES];
                    [array removeAllObjects];
                    count = 0;
                }

                sqlite3_finalize(stmt);
            }
            else {
                logString( @"Search LTO: prepare failed" );
            }
        }
		else {
			logString( @"Search LTO: failed to open database" );
		}
        
		sqlite3_close( ppDb );
		logString( @"Search LTO: Ending work\n" );

		[self completeOperation];		
		[pool release];
	}
	@catch(...) {
		// Do not rethrow exceptions.
	}
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
	
    executing = NO;
    finished = YES;
	
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isConcurrent
{
	return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}

@end
