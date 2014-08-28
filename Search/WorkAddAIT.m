//
//  WorkAddAIT.m
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import "WorkAddAIT.h"
#import "NSFileManager+DirectoryLocations.h"
#include "sqlite3.h"

extern void logString( NSString *log );
extern void logwindowf( char *formatString, ... );
extern int dotFolder(const char *path);
extern char *colon_convert( char *source );

#define BUFFER_SIZE 4096

@implementation WorkAddAIT

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
		directoryPath = [data retain];
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
	
	if (directoryPath != nil) {
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
				
		logString( @"Add AIT: Starting work\n" );
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *df = [fm applicationSupportDirectory];
		NSString *databasePath = [df stringByAppendingPathComponent:@"ait.sqlite"];
		
		ppDb = nil;
		int sql_err = 0;
		
		sql_err = sqlite3_open( [databasePath UTF8String], &ppDb );
		
		if (sql_err == 0) {
			FILE *fp = fopen([directoryPath UTF8String], "r");
			
			if (fp != nil) {
 				int sql_err = 0;
				char * sErrMsg = 0;
				char sSQL[BUFFER_SIZE] = "\0";
				const char *tail = 0;
				
				sprintf(sSQL, "INSERT INTO PATHS VALUES (NULL, @source, @path, @name);");

                sql_err = sqlite3_prepare_v2(ppDb, sSQL, BUFFER_SIZE, &stmt, &tail);
				
                if (stmt != NULL) {
                    sql_err = sqlite3_exec(ppDb, "BEGIN TRANSACTION", NULL, NULL, &sErrMsg);
                    
                    size_t len;
                    char *line_segment, *line_tape, *line_filename, *line_path;
					int lines = 0;
                    
                    while( (line_path = fgetln( fp, &len)) != NULL )
                    {
                        line_path[len-1] = 0;
                        line_segment = line_path + len - 2;
                        
                        while( line_segment > line_path && line_segment[0] != ' ' ) line_segment--;
                        
                        line_segment[0] = 0;
                        line_tape = line_segment -1;
                        
                        while( line_tape > line_path && line_tape[0] != ' ' ) line_tape--;
                        
                        line_tape[0] = 0;
                        line_filename = line_tape - 1;
                        
                        while( line_filename > line_path && line_filename[0] != '/' ) line_filename--;
                        
                        line_filename[0] = 0;
                        
						if ((lines++ % 50000) == 0) {
							logwindowf( "Add AIT: Processed %d lines\n", lines );
						}
                        
						if (strncmp(line_path, "/raid", 5) == 0) {
							line_path += 5;
						}
						
						if (strncmp(line_path, "/JOB_FOLDER", 11) == 0) {
							line_path += 11;
						}
						
						if (strncmp(line_path, "/   To Be Archived", 18) == 0) {
							line_path += 18;
						}
						
						if (line_path[0] == '/') {
							line_path += 1;
						}
						
                        if (line_path[0] == 0 ) continue;
                        if (line_filename[1] == 0 ) continue;
                        if (line_filename[1] == '.' ) continue;
                        if (dotFolder(line_path)) continue;
                        
                        sqlite3_bind_text(stmt, 1, line_tape+1, -1, SQLITE_TRANSIENT);
                        sqlite3_bind_text(stmt, 2, colon_convert(line_path), -1, free);
                        sqlite3_bind_text(stmt, 3, colon_convert(line_filename+1), -1, free);

						sqlite3_step(stmt);
                        
                        sqlite3_clear_bindings(stmt);
                        sqlite3_reset(stmt);
					}
                        
					sqlite3_exec(ppDb, "END TRANSACTION", NULL, NULL, &sErrMsg);
					sqlite3_finalize(stmt);
					stmt = 0;
				}
				else {
					logString( @"Add AIT: Prepared failed" );
				}
			}
			else {
				logString( @"Add AIT: failed to open LTO file." );
			}

			fclose(fp);
		}
		else {
			logString( @"Add AIT: failed to open database" );
		}

		sqlite3_close( ppDb );
		logString( @"Add AIT: Ending work\n" );

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
