//
//  Misc.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-09/27.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "Misc.h"

#define ACCOUNT_ID_NOW @"ACCOUNT_ID_NOW"

@implementation Misc

//NSDataオブジェクトの内容をもとに一時的なNSStringオブジェクトを発生する
//このとき文字コード変換はさせない
+ (NSString *)dataToString:(NSData *)iData;
{
	return [[[NSString alloc] initWithData:iData encoding:NSASCIIStringEncoding] autorelease];
}

//アカウントIDを発行する
+ (int)newAccountID
{
	NSUserDefaults *aUD = [NSUserDefaults standardUserDefaults];
	int aNewID = [aUD integerForKey:ACCOUNT_ID_NOW] + 1;

	[aUD setInteger:aNewID forKey:ACCOUNT_ID_NOW];
	[aUD synchronize];

	return aNewID;
}

//キーで示したLocalizable stringをNSMutableStringオブジェクトにして返す
//iKey=キー
//戻り値=求めるオブジェクト,一時的なものでないので明示的にreleaseする必要がある
+ (NSMutableString *)defaultMutableString:(NSString *)iKey
{
	return [[NSMutableString alloc] initWithString:NSLocalizedString(iKey,@"")];
}

// Pref書類に記録したオブジェクトを復元する
// iKey=記録キー
// 戻り値=復元したオブジェクト,復元できないならnil
// 復元したオブジェクトは一時的なものなので長期に保持するならretainして使うこと
+ (id)readDataPrefKey:(NSString *)iKey
{
	id aObj = nil;
	NSData *aData = [[NSUserDefaults standardUserDefaults] dataForKey:iKey];
	if(aData != nil){
		aObj = [NSUnarchiver unarchiveObjectWithData:aData];
	}
	return aObj;
}

+ (NSDictionary *)readDictPrefKey:(NSString *)iKey
{
	return [[NSUserDefaults standardUserDefaults] dictionaryForKey:iKey];
}

// Pref書類にオブジェクトを記録する
// iObject=記録したいオブジェクト,iKey=記録キー
+ (void)writeDataPref:(id)iObject key:(NSString *)iKey
{
	NSData *aData = [NSArchiver archivedDataWithRootObject:iObject];
	if(aData != nil){
		NSUserDefaults *aUD = [NSUserDefaults standardUserDefaults];
		[aUD setObject:aData forKey:iKey];
		[aUD synchronize];
	}
}

+ (void)writeDictPref:(NSDictionary *)iDict key:(NSString *)iKey
{
	NSUserDefaults *aUD = [NSUserDefaults standardUserDefaults];
	[aUD setObject:iDict forKey:iKey];
	[aUD synchronize];
}

// OSがVer.10.2以降かを確認する
// 戻り値=YESなら10.2またはそれ以降,NOなら10.2よりも前のヴァージョン
+ (BOOL)is_10_2_or_later_version
{
	OSErr aErr;
	SInt32 aVersion;

	aErr = Gestalt(gestaltSystemVersion,&aVersion);
	if(aErr == noErr){
		if(aVersion >= 0x1020){
			return YES;
		}
	}
	return NO;
}

@end

//特定の文字列を探すが、探されるほうの文字列を大文字化してから探す
//iText=探されるほうの文字列,iSearch=探す文字列(英小文字は絶対に含まないこと)
char *strstr_touppered(const char *iText,const char *iSearch)
{
	while(*iText != 0){
		const char *aText = iText;
		const char *aSearch = iSearch;
		BOOL aLoop;
		do{
			if(*aSearch == 0){
				return (char *)iText;
			}
			aLoop = (toupper(*aText) == *aSearch);
			if(aLoop){
				++aText;
				++aSearch;
			}
		}while(aLoop);
		++iText;
	}
	return NULL;
}

// End Of File
