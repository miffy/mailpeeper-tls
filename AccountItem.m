//
//  AccountItem.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-09/15.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "AccountItem.h"
#import "Misc.h"

static BOOL isStringLengthBad(NSString *iString)
{
	return (iString == nil || [iString length] == 0);
}

@implementation AccountItem

//巡回しないならYES,するならNOを返す
- (BOOL)notUse
{
	return mNotUse;
}

//巡回の設定
//iNotUse=YESなら巡回しない,NOなら巡回する
- (void)setNotUse:(BOOL)iNotUse
{
	mNotUse = iNotUse;
}

//内部状態の変更
//検証でNGなら変更はしない
//iData=変更データ
//戻り値=検証結果
- (AccountItem_change_t)change:(AccountItem_record_t *)iData
{
	//アカウント名の検証
	if(isStringLengthBad(iData->mAccountName)){
		return AIC_Account;
	}
	
	//POP3サーバー名の検証
	if(isStringLengthBad(iData->mPop3Server)){
		return AIC_Pop3;
	}
	
	//ポート番号の検証
	if(iData->mPortNo < 1 || iData->mPortNo > 0x7fff){
		return AIC_PortNo;
	}

	//ユーザー名の検証
	if(isStringLengthBad(iData->mUserName)){
		return AIC_UserName;
	}

	//パスワードの検証
	if(isStringLengthBad(iData->mPassWord)){
		return AIC_PassWord;
	}

	//OK
	[mR.mAccountName setString:iData->mAccountName];
	[mR.mPop3Server setString:iData->mPop3Server];
	mR.mPortNo = iData->mPortNo;
	[mR.mUserName setString:iData->mUserName];
	[mR.mPassWord setString:iData->mPassWord];
	mR.mTLS = iData->mTLS;

	return AIC_OK;
}

//アカウントIDをえる
- (int)accountID
{
	return mAccountID;
}

//アカウント名をえる
- (NSString *)accountName
{
	return mR.mAccountName;
}

//POP3サーバー名をえる
- (NSString *)pop3Server
{
	return mR.mPop3Server;
}

//ポート番号
- (unsigned short)portNo
{
	return mR.mPortNo;
}

//ユーザー名
- (NSString *)userName
{
	return mR.mUserName;
}

//パスワード
- (NSString *)passWord
{
	return mR.mPassWord;
}

//TLS使用
- (int)tls
{
	return mR.mTLS;
}

//空白状態からの初期化
- (id)init
{
	if((self = [super init]) != nil){
		mR.mAccountName = [Misc defaultMutableString:@"DEFAULT_ACCOUNT"];
		mR.mPop3Server = [Misc defaultMutableString:@"DEFAULT_POP3"];
		mR.mPortNo = 110;
		mR.mUserName = [Misc defaultMutableString:@"DEFAULT_USER"];
		mR.mPassWord = [Misc defaultMutableString:@"DEFAULT_PASS"];
		mR.mTLS = (int)NO;
	}
	return self;
}

//終了化
- (void)dealloc
{
	[mR.mAccountName release]; 	//アカウント名
	[mR.mPop3Server release];  	//POP3サーバー名
	[mR.mUserName release];		//ユーザー名
	[mR.mPassWord release];		//パスワード

	[super dealloc];
}

//アカウントIDを変更する
- (void)setAccountID:(int)iID
{
	mAccountID = iID;
}

//エンコード
- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeObject:mR.mAccountName];
	[encoder encodeObject:mR.mPop3Server];
	[encoder encodeValueOfObjCType:@encode(int) at:&mR.mPortNo];
	[encoder encodeObject:mR.mUserName];
	[encoder encodeObject:mR.mPassWord];
	[encoder encodeValueOfObjCType:@encode(int) at:&mAccountID];
	[encoder encodeValueOfObjCType:@encode(int) at:&mR.mTLS];
}

//デコード
- (id)initWithCoder:(NSCoder *)decoder
{
	if((self = [super init]) != nil){
		mR.mAccountName = [[decoder decodeObject] retain];
		mR.mPop3Server = [[decoder decodeObject] retain];
		[decoder decodeValueOfObjCType:@encode(int) at:&mR.mPortNo];
		mR.mUserName = [[decoder decodeObject] retain];
		mR.mPassWord = [[decoder decodeObject] retain];
		[decoder decodeValueOfObjCType:@encode(int) at:&mAccountID];
		[decoder decodeValueOfObjCType:@encode(int) at:&mR.mTLS];
	}
	return self;
}

@end

// End Of File
