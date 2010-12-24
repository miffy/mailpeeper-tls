//
//  UIDLHelpItem.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/15-09/27.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UIDLHelpItem : NSObject {
	BOOL mError;  //エラー検出フラグ
	BOOL mFinish; //終結検出フラグ
	
	int mNo;		//番号
	NSString *mUID;	//UID文字列
	int mAccountID;	//アカウントID

	int mNewMailNo; //新規メールだった場合、何通目(1〜)だったか
}
+ (id)createItem:(NSData *)iData accountID:(int)iID;
- (id)initWithUIDLData:(NSData *)iData accountID:(int)iID;
- (BOOL)error;
- (BOOL)finish;
- (int)number;
- (NSString *)uid;
- (int)accountID;
- (void)setNewMailNo:(int)iNo;
- (int)newMailNo;
@end

// End Of File
