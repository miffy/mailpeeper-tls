//
//  HeaderAnalizer.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/15-09/16.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HeaderAnalizer : NSObject {
	NSMutableDictionary *mDataDict; //(keyはNSString,valueはNSMutableDataの辞書)
	NSMutableArray *mDataArray;     //(NSMutableData配列)
	NSMutableData *mLastData;
}

- (void)push:(NSData *)iData;
- (void)pushEnd;
- (NSString *)pop:(NSString *)iKey decodeJis:(BOOL)iDecodeJis;

@end

// End Of File
