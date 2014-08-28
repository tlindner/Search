//
//  WorkAddDMG.m
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import "WorkAddDMG.h"
#import "NSFileManager+DirectoryLocations.h"
#include "sqlite3.h"

extern void logString( NSString *log );
extern void logwindowf( char *formatString, ... );
extern int dotFolder(const char *path);

sqlite3 *ppDb;
sqlite3_stmt *stmt;

#define BUFFER_SIZE 4096

@implementation WorkAddDMG

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

		logString( @"Add DMG: Starting work\n" );
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *df = [fm applicationSupportDirectory];
		NSString *databasePath = [df stringByAppendingPathComponent:@"storage.sqlite"];
		
		ppDb = nil;
		int sql_err = 0;
		
		sql_err = sqlite3_open( [databasePath UTF8String], &ppDb );
		
		if (sql_err == 0) {
            [self processDMGsPath:directoryPath withItems:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:directoryPath error:nil]];
        }
        
		logString( @"Add DMG: Ending work\n" );

		sqlite3_close( ppDb );
		[self completeOperation];
		[pool release];
	}
	@catch(...) {
		// Do not rethrow exceptions.
	}
}

- (void)processDMGsPath:(NSString *)path withItems:(NSArray *)dirFiles
{
    for (NSString *item in dirFiles) {
        
		if ([self isCancelled]) {
			break;
		}
			
		NSString *fullItem = [path stringByAppendingPathComponent:item];
        
        if ([item hasPrefix:@"."]) {
            logString( [NSString stringWithFormat:@"Add DMG: Skipping: %@ (dot file)\n", fullItem] );
            continue;
        }
        
        BOOL isDirectory;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullItem isDirectory:&isDirectory]) {
            if (isDirectory == YES) {
                [self processDMGsPath:fullItem withItems:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:fullItem error:nil]];
            }
            else if ([item hasSuffix:@".dmg"]) {
                if (![self inDatabase:item]) {
                    NSString *devPath;
					logString( [NSString stringWithFormat:@"Add DMG: %@ - ", item] );
					NSString *mountPoint = [self mountDMG:fullItem dev:&devPath];
                    
                    if (mountPoint != nil) {
                        [self addVolume:mountPoint dmgName:item];
                        if( ![self unmountDMG:devPath])
						{
							logString(@"\nAdd DMG: Trying unmount one more time…\n");
							sleep(5);
							if (![self unmountDMG:devPath]) {
								logString(@"Add DMG: Unmount failure\n");
								[self cancel];
							}
							else {
								logString(@"Add DMG: Unmount success\n");
							}

						}
						
						logString(@"\n");
                    }
                    else {
                        logString( [NSString stringWithFormat:@"Add DMG: Skipping: %@ (failed to mount DMG)\n", fullItem] );
                    }
                }
                else {
                    //logString( [NSString stringWithFormat:@"Add DMG: Skipping: %@ (already in database)\n", fullItem] );
                }
            }
            else {
                logString( [NSString stringWithFormat:@"Add DMG: Skipping: %@ (not DMG)\n", fullItem] );
            }
        }
    }
}

- (NSString *)mountDMG:(NSString *)dmgFile dev:(NSString **)devPath
{
//	logString( [NSString stringWithFormat:@"Add DMG: Mounting: %@\n", dmgFile] );
    *devPath = nil;
    NSString *result = nil;
    NSTask *task = [[NSTask alloc] init];
    NSArray *arguments = [NSArray arrayWithObjects: @"attach", @"-plist", @"-readonly", @"-nobrowse", @"-noverify", dmgFile, nil];
    //    NSArray *arguments = [NSArray arrayWithObjects: @"attach", @"-plist", @"-readonly", @"-noverify", dmgFile, nil];
    [task setLaunchPath:@"/usr/bin/hdiutil"];
    [task setArguments:arguments];
    NSPipe *stdOut = [[NSPipe alloc] init];
    NSPipe *stdErr = [[NSPipe alloc] init];
    [task setStandardOutput:stdOut];
    [task setStandardError:stdErr];
	logString( @"m" );
    [task launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    
    if (status == 0) {
		logString( @"M" );
        NSFileHandle *fileHandleForReadingOutput = [stdOut fileHandleForReading];
        NSData *outputData = [fileHandleForReadingOutput readDataToEndOfFile];
        NSDictionary *outputDict = [NSDictionary dictionaryWithContentsOfData:outputData];
        NSArray *system_entities = [outputDict objectForKey:@"system-entities"];
        
        for (NSDictionary *entity in system_entities) {
            NSNumber *pm = [entity objectForKey:@"potentially-mountable"];
            
            if ([pm boolValue]) {
                *devPath = [entity objectForKey:@"dev-entry"];
                result = [entity objectForKey:@"mount-point"];
                break;
            }
        }
    }
    else {
        NSFileHandle *fileHandleForReadingErr = [stdErr fileHandleForReading];
		NSString *errorString = [[[NSString alloc] initWithData:[fileHandleForReadingErr readDataToEndOfFile] encoding:NSUTF8StringEncoding] autorelease];
        logString( [NSString stringWithFormat:@"\nAdd DMG: hdiutil error: %d\nAdd DMG: Error: %@\nAdd DMG: Stopping", errorString, status] );
		[self cancel];
    }
    
	[stdErr release];
    [stdOut release];
    [task release];
    return result;
}

- (BOOL)unmountDMG:(NSString *)devPath
{
	BOOL result = YES;
    NSTask *task = [[NSTask alloc] init];
    NSArray *arguments = [NSArray arrayWithObjects: @"detach", devPath, nil];
    [task setLaunchPath:@"/usr/bin/hdiutil"];
    [task setArguments:arguments];
    NSPipe *stdOut = [[NSPipe alloc] init], *stdErr = [[NSPipe alloc] init];
    [task setStandardOutput:stdOut];
    [task setStandardError:stdErr];
    [task launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    
    if (status != 0) {
		NSString *sOut = [[[NSString alloc] initWithData:[[stdOut fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding] autorelease];
		NSString *sErr = [[[NSString alloc] initWithData:[[stdErr fileHandleForReading] readDataToEndOfFile] encoding: NSUTF8StringEncoding] autorelease];
        logString( [NSString stringWithFormat:@"Add DMG: hdiutil error detaching (%d): %@\nAdd DMG: Output: %@\nAdd DMG: Error: %@\n", status, devPath, sOut, sErr] );
		result = NO;
	}
    
    [stdOut release];
    [stdErr release];
    [task release];
	
	return result;
}

- (BOOL)inDatabase:(NSString *)item
{
    BOOL result = NO;
    int count = 0;
    const char *tail;
	int sql_err = 0;
//	char * sErrMsg = 0;

    if (stmt != 0) {
        sqlite3_finalize(stmt);
        stmt = 0;
    }
    
    /* get count of results */
	sql_err = sqlite3_prepare_v2(ppDb, "SELECT count(*) FROM DMGS WHERE name IS @path;", -1, &stmt, &tail);
    
	if (stmt != NULL) {
	
		sql_err = sqlite3_bind_text(stmt, 1, [[item stringByDeletingPathExtension] UTF8String], -1, SQLITE_TRANSIENT);
		sql_err = sqlite3_step(stmt);
		
		if (sql_err == SQLITE_ROW) {
			count = sqlite3_column_int(stmt, 0);
		}
		
		sql_err = sqlite3_finalize(stmt);
		stmt = 0;

		if (count > 0) {
			result = YES;
		}
		else {
			/* add DMG to database */
			sql_err = sqlite3_prepare_v2(ppDb, "INSERT INTO DMGS VALUES (NULL, @path);", -1, &stmt, &tail);
			
			if (sql_err != SQLITE_OK) {
				logString( @"Add DMG: Error preparing query.\n");
				result = YES;
				[self cancel];
			}

			sql_err = sqlite3_bind_text(stmt, 1, [[item stringByDeletingPathExtension] UTF8String], -1, SQLITE_TRANSIENT);
			
			if (sql_err != SQLITE_OK) {
				logString( @"Add DMG: Error binding dmg name to query.\n");
				result = YES;
				[self cancel];
			}

			sql_err = sqlite3_step(stmt);
			
			if (sql_err != SQLITE_DONE) {
				logString( @"Add DMG: Error stepping query.\n");
				result = YES;
				[self cancel];
			}

			sql_err = sqlite3_finalize(stmt);
			stmt = 0;
			
			if (sql_err != SQLITE_OK) {
				logString( @"Add DMG: Error finializing query.\n");
				result = YES;
				[self cancel];
			}
		}
	}
	else {
		logString( @"Add DMG: Prepared failed (inDatabase)\n" );
		result = YES;
		[self cancel];
	}

    return result;
}

- (void)addVolume:(NSString *)mountPoint dmgName:(NSString *)dmgName
{
    /* setup data base connection */
    int sql_err = 0;
    char * sErrMsg = 0;
    char sSQL[BUFFER_SIZE] = "\0";
    const char *tail = 0;
    
	logString( @"v" );
	
    sprintf(sSQL, "INSERT INTO PATHS VALUES (NULL, @source, @path, @name);");
    
    if (stmt != 0) {
        sqlite3_finalize(stmt);
        stmt = 0;
    }
    
    sql_err = sqlite3_prepare_v2(ppDb, sSQL, BUFFER_SIZE, &stmt, &tail);
    
    if (stmt != NULL) {
		sql_err = sqlite3_exec(ppDb, "BEGIN TRANSACTION", NULL, NULL, &sErrMsg);
		
		/* insert away! */
		NSInteger chop = [[mountPoint stringByDeletingLastPathComponent] length] + 1;
		
		[self addSubVolume:mountPoint chop:chop dmgName:dmgName];
		
		/* clean up database op */
		sqlite3_exec(ppDb, "END TRANSACTION", NULL, NULL, &sErrMsg);
		sqlite3_finalize(stmt);
		stmt = 0;
	}
	else {
		logString( @"Add DMG: Prepared failed (addVolume)\n" );
	}
	
	logString( @"v" );

}

- (void)addSubVolume:(NSString *)mountPoint chop:(NSInteger)chop dmgName:(NSString *)dmgName
{

    NSArray *dirEntries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:mountPoint error:nil];
    NSString *choppedPath = [mountPoint substringFromIndex:chop];
    
    for (NSString *filename in dirEntries) {
        if (![filename hasPrefix:@"."]) {
            NSString *fullPath = [mountPoint stringByAppendingPathComponent:filename];
            BOOL isDirectory;
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory]) {
//				logString( [NSString stringWithFormat:@"Add DMG: adding: %@/%@\n", choppedPath, filename] );               
                sqlite3_bind_text(stmt, 1, [dmgName UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(stmt, 2, [choppedPath UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(stmt, 3, [filename UTF8String], -1, SQLITE_TRANSIENT);
                
                sqlite3_step(stmt);
                
                sqlite3_clear_bindings(stmt);
                sqlite3_reset(stmt);
                
                if (isDirectory == YES) {
                    [self addSubVolume:fullPath chop:chop dmgName:dmgName];
                }
            }
        }
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

@implementation NSDictionary (Helpers2)

+ (NSDictionary *)dictionaryWithContentsOfData:(NSData *)data
{
	// uses toll-free bridging for data into CFDataRef and CFPropertyList into NSDictionary
	CFPropertyListRef plist =  CFPropertyListCreateFromXMLData(kCFAllocatorDefault, (CFDataRef)data,
															   kCFPropertyListImmutable,
															   NULL);
	// we check if it is the correct type and only return it if it is
	if ([(id)plist isKindOfClass:[NSDictionary class]])
	{
		return [(NSDictionary *)plist autorelease];
	}
	else
	{
		// clean up ref
		CFRelease(plist);
		return nil;
	}
}

@end

