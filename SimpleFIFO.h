//
//  SimpleFIFO.h
//
//  Created by Dentom on 2002/10/06.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

struct SimpleFIFO_Cell;

@interface SimpleFIFO : NSObject {
	struct SimpleFIFO_Cell *mCellTop;
	struct SimpleFIFO_Cell *mCellLast;
	unsigned int mCellCount;
}
- (unsigned int)count;
- (void)push:(id)iObj;
- (id)pop;

@end

// End Of File
