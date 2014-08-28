//
//  WorkCheckStorage.m
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import "WorkCheckStorage.h"
#import "NSFileManager+DirectoryLocations.h"
#include "sqlite3.h"

extern void logString( NSString *log );
extern void logwindowf( char *formatString, ... );
extern int dotFolder(const char *path);

#define BUFFER_SIZE 4096

@implementation WorkCheckStorage

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
		
		logString( @"Check Storage: Starting work\n" );
		sqlite3_temp_directory = (char *)[NSTemporaryDirectory() UTF8String];
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *df = [fm applicationSupportDirectory];
		NSString *databasePath = [df stringByAppendingPathComponent:@"storage.sqlite"];
		
		ppDb = nil;
		int sql_err = 0;
		const char *tail = 0;
        
		sql_err = sqlite3_open( [databasePath UTF8String], &ppDb );
		
		if (sql_err == 0) {
			NSString *getAllDMGs = @"SELECT name FROM DMGS;";

			sql_err = sqlite3_prepare_v2(ppDb, [getAllDMGs UTF8String], -1, &stmt, &tail);
			
			if (stmt != NULL) {
				
				do {
					sql_err = sqlite3_step(stmt);
					
					if (sql_err == SQLITE_ROW) {
						const unsigned char *dmgName = sqlite3_column_text(stmt, 0);
						NSString *getCountPaths = [NSString stringWithFormat:@"SELECT count(*) FROM PATHS WHERE path LIKE '%s%%';", dmgName];
						sqlite3_stmt *stmtCount = 0;
						int count = 0;

						sql_err = sqlite3_prepare_v2(ppDb, [getCountPaths UTF8String], -1, &stmtCount, &tail);
						
						if (stmt != NULL) {
							sql_err = sqlite3_step(stmtCount);
							
							if (sql_err == SQLITE_ROW) {
								count = sqlite3_column_int(stmtCount, 0);
							}
							
							sqlite3_finalize(stmtCount);

							if (count == 0) {
								logString([NSString stringWithFormat:@"Check Storage: DMG: %s, Path count: %d\n", dmgName, count]);
							}
						}
					}
				} while (sql_err == SQLITE_ROW);
				
				sqlite3_finalize(stmt);

			}
			else {
				logString( @"Check Storage: Prepared failed (main)\n" );
			}
		}
		else {
			logString( @"Check Storage: failed to open database" );
		}
        
		sqlite3_close( ppDb );
		logString( @"Check Storage: Ending work\n" );

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
