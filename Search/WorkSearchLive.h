//
//  WorkSearchLive.h
//  Search
//
//  Created by Tim on 3/31/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface WorkSearchLive : NSOperation {
	NSString *searchQuery;
	
    BOOL        executing;
    BOOL        finished;
}

- (id)initWithString:(NSString *)data;
- (void)completeOperation;

@end
