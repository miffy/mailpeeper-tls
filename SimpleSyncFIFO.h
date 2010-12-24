//
//  SimpleSyncFIFO.h
//
//  Created by Dentom on 2002/10/06.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import "SimpleFIFO.h"

@interface SimpleSyncFIFO : SimpleFIFO {
	NSLock *mLock;
}
- (unsigned int)count;
- (void)push:(id)iObj;
- (id)pop;
- (id)popEasy;

@end

// End Of File
