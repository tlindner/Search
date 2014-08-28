//
//  WorkAddLTO.h
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface WorkAddLTO : NSOperation {
	NSString *directoryPath;
	
    BOOL        executing;
    BOOL        finished;
}

- (id)initWithString:(NSString *)data;
- (void)completeOperation;

@end
