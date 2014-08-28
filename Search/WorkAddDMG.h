//
//  WorkAddDMG.h
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface WorkAddDMG : NSOperation {
	NSString *directoryPath;
	
    BOOL        executing;
    BOOL        finished;
}

- (void)processDMGsPath:(NSString *)path withItems:(NSArray *)dirFiles;
- (BOOL)inDatabase:(NSString *)item;
- (NSString *)mountDMG:(NSString *)dmgFile dev:(NSString **)devPath;
- (BOOL)unmountDMG:(NSString *)devPath;
- (void)addVolume:(NSString *)mountPoint dmgName:(NSString *)dmgName;
- (void)addSubVolume:(NSString *)mountPoint chop:(NSInteger)chop dmgName:(NSString *)dmgName;

- (id)initWithString:(NSString *)data;
- (void)completeOperation;

@end

@interface NSDictionary (Helpers2)

+ (NSDictionary *)dictionaryWithContentsOfData:(NSData *)data;

@end
