//
//  GeneralItem.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/13-10/04.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "GeneralItem.h"

#define GoAtStart_Key 			@"GoAtStart"
#define Repeat_Key 				@"Repeat"
#define RepeatMinute_Key		@"RepeatMinute"
#define NewMailVoiceEnable_Key	@"NewMailVoiceEnable"
#define NewMailVoiceText_Key	@"NewMailVoiceText"
#define ErrorVoiceEnable_Key	@"ErrorVoiceEnable"
#define ErrorVoiceText_Key		@"ErrorVoiceText"

#define GoAtResume_Key			@"GoAtResume"
#define NewMailSoundEnable_Key	@"NewMailSoundEnable"
#define NewMailSoundPath_Key	@"NewMailSoundPath"
#define ErrorSoundEnable_Key	@"ErrorSoundEnable"
#define ErrorSoundPath_Key		@"ErrorSoundPath"

@implementation GeneralItem

//プログラム起動時に巡回開始ならYES
- (BOOL)goAtStart
{
	return mR.mGoAtStart;
}

//定期的に巡回するならYES
- (BOOL)repeat
{
	return mR.mRepeat;
}

//巡回する間隔(分)
- (int)repeatMinute
{
	return mR.mRepeatMinute;
}

//新規メール時に音声を出すかを返す
- (BOOL)newMailVoiceEnable
{
	return mR.mNewMailVoiceEnable;
}

//新規メール時の音声データ
- (NSString *)newMailVoiceText
{
	return mR.mNewMailVoiceText;
}

//エラー時に音声を出すかを返す
- (BOOL)errorVoiceEnable
{
	return mR.mErrorVoiceEnable;
}

//エラー時の音声データ
- (NSString *)errorVoiceText
{
	return mR.mErrorVoiceText;
}

//レジューム時の巡回開始ならYES
- (BOOL)goAtResume
{
	return mR.mGoAtResume;
}

//音でお知らせ関連
- (BOOL)newMailSoundEnable
{
	return mR.mNewMailSoundEnable;
}
- (NSString *)newMailSoundPath
{
	return mR.mNewMailSoundPath;
}
- (BOOL)errorSoundEnable
{
	return mR.mErrorSoundEnable;
}
- (NSString *)errorSoundPath
{
	return mR.mErrorSoundPath;
}


//記録対象フィールドを変更する
//戻り値=YESなら変更した,NOなら変更できない
- (BOOL)change:(GeneralItem_rec_t *)iData
{
	//巡回する間隔が1分より小さいならダメ
	if(iData->mRepeat && iData->mRepeatMinute < 1){
		return NO;
	}

	[mR.mNewMailVoiceText autorelease];
	[mR.mErrorVoiceText autorelease];
	mR = *iData;
	mR.mNewMailVoiceText = [iData->mNewMailVoiceText copy];
	mR.mErrorVoiceText = [iData->mErrorVoiceText copy];

	return YES;
}

//終了化
- (void)dealloc
{
	[mR.mNewMailVoiceText release];
	
	[super dealloc];
}

//空白状態からの初期化
- (id)init
{
	if((self = [super init]) != nil){
		mR.mRepeatMinute = 30;
		mR.mNewMailVoiceText = [[NSString alloc] initWithString:@"You've got mail."];
		mR.mErrorVoiceText = [[NSString alloc] initWithString:@"MailPeeper needs your attention."];
		mR.mNewMailSoundPath = [[NSString alloc] initWithString:@"/System/Library/Sounds/Hero.aiff"];
		mR.mErrorSoundPath = [[NSString alloc] initWithString:@"/System/Library/Sounds/Frog.aiff"];
	}
	return self;
}

//Pref書類に記録していた情報を元に復元する
//iInf=情報保持辞書
- (void)recoverInf:(id)iInf
{
	NSDictionary *aDict = iInf;
	id aObj;

	mR.mGoAtStart = [[aDict objectForKey:GoAtStart_Key] boolValue];
	mR.mRepeat =  [[aDict objectForKey:Repeat_Key] boolValue];
	mR.mRepeatMinute = [[aDict objectForKey:RepeatMinute_Key] intValue];
	mR.mNewMailVoiceEnable = [[aDict objectForKey:NewMailVoiceEnable_Key] boolValue];
	aObj = [aDict objectForKey:NewMailVoiceText_Key];
	if(aObj != nil){
		[mR.mNewMailVoiceText autorelease];
		mR.mNewMailVoiceText = [aObj retain];
	}
	mR.mErrorVoiceEnable = [[aDict objectForKey:ErrorVoiceEnable_Key] boolValue];
	aObj = [aDict objectForKey:ErrorVoiceText_Key];
	if(aObj != nil){
		[mR.mErrorVoiceText autorelease];
		mR.mErrorVoiceText = [aObj retain];
	}
	
	// add at tls
	mR.mGoAtResume = [[aDict objectForKey:GoAtResume_Key] boolValue];
	mR.mNewMailSoundEnable = [[aDict objectForKey:NewMailSoundEnable_Key] boolValue];
	aObj = [aDict objectForKey:NewMailSoundPath_Key];
	if(aObj != nil){
		[mR.mNewMailSoundPath autorelease];
		mR.mNewMailSoundPath = [aObj retain];
	}
	mR.mErrorSoundEnable = [[aDict objectForKey:ErrorSoundEnable_Key] boolValue];
	aObj = [aDict objectForKey:ErrorSoundPath_Key];
	if(aObj != nil){
		[mR.mErrorSoundPath autorelease];
		mR.mErrorSoundPath = [aObj retain];
	}	
}

//Pref書類に記録したい情報を返す
- (id)saveInf
{
	NSMutableDictionary *aDict = [NSMutableDictionary dictionary];

	[aDict setObject:[NSNumber numberWithBool:mR.mGoAtStart] forKey:GoAtStart_Key];
	[aDict setObject:[NSNumber numberWithBool:mR.mRepeat] forKey:Repeat_Key];
	[aDict setObject:[NSNumber numberWithInt:mR.mRepeatMinute] forKey:RepeatMinute_Key];
	[aDict setObject:[NSNumber numberWithBool:mR.mNewMailVoiceEnable] forKey:NewMailVoiceEnable_Key];
	[aDict setObject:mR.mNewMailVoiceText forKey:NewMailVoiceText_Key];
	[aDict setObject:[NSNumber numberWithBool:mR.mErrorVoiceEnable] forKey:ErrorVoiceEnable_Key];
	[aDict setObject:mR.mErrorVoiceText forKey:ErrorVoiceText_Key];
	// add at tls
	[aDict setObject:[NSNumber numberWithBool:mR.mGoAtResume] forKey:GoAtResume_Key];
	[aDict setObject:[NSNumber numberWithBool:mR.mNewMailSoundEnable] forKey:NewMailSoundEnable_Key];
	[aDict setObject:mR.mNewMailSoundPath forKey:NewMailSoundPath_Key];
	[aDict setObject:[NSNumber numberWithBool:mR.mErrorSoundEnable] forKey:ErrorSoundEnable_Key];
	[aDict setObject:mR.mErrorSoundPath forKey:ErrorSoundPath_Key];
	
	return aDict;
}

@end

// End Of File









































//エンコード
/*- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeValueOfObjCType:@encode(GeneralItem_record_t) at:&mR];
}*/

//デコード
/*- (id)initWithCoder:(NSCoder *)decoder
{
	if((self = [super init]) != nil){
		[decoder decodeValueOfObjCType:@encode(GeneralItem_record_t) at:&mR];
	}
	return self;
}*/


