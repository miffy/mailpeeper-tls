//
//  UIDLHelpItem.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/15-09/27.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "UIDLHelpItem.h"
#import "Misc.h"

@implementation UIDLHelpItem

//一時的なインスタンスの作成
//iData=UIDL情報,iID=アカウントID
+ (id)createItem:(NSData *)iData accountID:(int)iID
{
	return [[[UIDLHelpItem alloc] initWithUIDLData:iData accountID:iID] autorelease];
}

//初期化メソッド
//iData=UIDL情報,iID=アカウントID
- (id)initWithUIDLData:(NSData *)iData accountID:(int)iID
{
	if((self = [super init]) != nil){
		NSString *aString = [Misc dataToString:iData];
		//情報が"."であれば終結している
		if([aString isEqualToString:@".\r\n"]){
			mFinish = YES;
		}else{
			//情報は"番号 UID文字列"であるはず
			NSScanner *aScanner = [NSScanner scannerWithString:aString];
			//番号,UID文字列を取り出す
			if([aScanner scanInt:&mNo] && [aScanner scanUpToString:@"\r" intoString:&aString]){
				mUID = [aString retain];
				mAccountID = iID;
				if(mNo < 1){ //(まずありえないと思うが念のため)
					mError = YES;
				}
			}else{
				mError = YES;
			}
		}
	}
	return self;
}

//終了化メソッド
- (void)dealloc
{
	[mUID release];

	[super dealloc];
}

//エラー検出時はYESを返す
- (BOOL)error
{
	return mError;
}

//集結の検出時はYESを返す
- (BOOL)finish
{
	return mFinish;
}

//番号をえる
- (int)number
{
	return mNo;
}

//UIDをえる
- (NSString *)uid
{
	return mUID;
}

//アカウントIDをえる
- (int)accountID
{
	return mAccountID;
}

//何通目の新規メールだったかを設定する
- (void)setNewMailNo:(int)iNo
{
	mNewMailNo = iNo;
}

//何通目の新規メールだったかをえる
- (int)newMailNo
{
	return mNewMailNo;
}

@end

// End Of File
