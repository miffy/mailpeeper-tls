//
//  PeepedItem.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-09/22.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "PeepedItem.h"
#import "HeaderAnalizer.h"
#import "Misc.h"

@implementation PeepedItem

//ヘッダー情報を解釈し、表示や保存にそなえる
- (void)analizeHeader
{
	HeaderAnalizer *aHA = [[[HeaderAnalizer alloc] init] autorelease];
	NSEnumerator *aItr = [mHeadArray objectEnumerator];
	NSData *aData;
	
	//順番にヘッダー情報を押し込んでいく
	while((aData = [aItr nextObject]) != nil){
		[aHA push:aData];
	}
	[aHA pushEnd];

	//From:情報をえる
	[mFrom autorelease];
	mFrom = [[aHA pop:@"FROM" decodeJis:YES] retain];

	//Subject:情報をえる
	[mSubject autorelease];
	mSubject = [[aHA pop:@"SUBJECT" decodeJis:YES] retain];

	//Date:情報をえる
	[mDate autorelease];
	mDate = [[aHA pop:@"DATE" decodeJis:NO] retain];
}

//TOPコマンドの結果を追加登録する
- (void)appendTOPdata:(NSData *)iData
{
	//NSLog(@"PeepedItem.appendTOPdata:%@",iData);
	if(mHeadArray == nil){
		mHeadArray = [[NSMutableArray alloc] init];
	}
	[mHeadArray addObject:iData];
}

//From:をえる
- (NSString *)from
{
	return mFrom;
}

//Subject:をえる
- (NSString *)subject
{
	return mSubject;
}

//Date:をえる
- (NSString *)date
{
	return mDate;
}

//UIDを設定する
- (void)setUID:(NSString *)iUID
{
	[mUID autorelease];
	mUID = [iUID retain];
}

//UIDをえる
- (NSString *)uid
{
	return mUID;
}

//保存フラグを設定する
- (void)setSaveFlag:(BOOL)iFlag
{
	mSaveFlag = iFlag;
}

//保存フラグをえる
- (BOOL)saveFlag
{
	return mSaveFlag;
}

//新規メール印を設定する
- (void)setNewMailFlag:(BOOL)iFlag
{
	mNewMailFlag = iFlag;
}

//新規メール印をえる
- (NSString *)newMailMark
{
	static NSString *aMark = nil;
	
	if(aMark == nil){
		aMark = NSLocalizedString(@"NEW_MAIL_MARK",@"");
	}
	
	return mNewMailFlag ? aMark : @"";
}

//アカウントIDを変更する
- (void)setAccountID:(int)iID
{
	mAccountID = iID;
}

//アカウントIDをえる
- (int)accountID
{
	return mAccountID;
}

//メールのサイズを変更する
- (void)setMailSize:(int)iSize
{
	mMailSize = iSize;
}

//メールのサイズをえる
- (int)mailSize
{
	return mMailSize;
}

//ヘッダの全内容を返す
- (NSString *)allHeader
{
	NSMutableString *aAns = [NSMutableString string];
	NSEnumerator *aItr = [mHeadArray objectEnumerator];
	NSData *aData;
	while((aData = [aItr nextObject]) != nil){
		[aAns appendString:[Misc dataToString:aData]];
	}
	
	return aAns;
}

//終了化
- (void)dealloc
{
	[mUID release];
	[mHeadArray release];
	[mFrom release];
	[mSubject release];
	[mDate release];
	
	[super dealloc];
}

//エンコード
- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeValueOfObjCType:@encode(int) at:&mAccountID];
	[encoder encodeObject:mUID];
	[encoder encodeValueOfObjCType:@encode(int) at:&mMailSize];
	[encoder encodeObject:mHeadArray];
	[encoder encodeObject:mFrom];
	[encoder encodeObject:mSubject];
	[encoder encodeObject:mDate];
}

//デコード
- (id)initWithCoder:(NSCoder *)decoder
{
	if((self = [super init]) != nil){
		[decoder decodeValueOfObjCType:@encode(int) at:&mAccountID];
		mUID = [[decoder decodeObject] retain];
		[decoder decodeValueOfObjCType:@encode(int) at:&mMailSize];
		mHeadArray = [[decoder decodeObject] retain];
		mFrom = [[decoder decodeObject] retain];
		mSubject = [[decoder decodeObject] retain];
		mDate = [[decoder decodeObject] retain];
	}
	return self;
}

@end

// End Of File
