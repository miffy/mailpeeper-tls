//
//  HeaderAnalizer.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/15-09/27.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "HeaderAnalizer.h"
#import "Misc.h"

static void decodeBase64(char *iTextTop);

@implementation HeaderAnalizer

//初期化メソッド
- (id)init
{
	if((self = [super init]) != nil){
		mDataArray = [[NSMutableArray alloc] init];
		mDataDict = [[NSMutableDictionary alloc] init];
	}
	return self;
}

//終了化メソッド
- (void)dealloc
{
	[mDataDict release];
	[mDataArray release];

	[super dealloc];
}

//ヘッダー情報の1行を持ち込む
- (void)push:(NSData *)iData
{
	int aDataLength = [iData length];
	//持ち込まれたデータの最初のバイトが20hまたは09hなら前のデータの続きと解釈する
	if(aDataLength > 1){
		const char *aDataTop = (const char *)[iData bytes];
		char aCh = *aDataTop;
		if((aCh == 0x20 || aCh == 0x09) && (mLastData != nil)){
			//その場合、データの先頭1バイトを除去したものを前のデータに連結する
			//また前のデータの末尾(CR+LF)を除去しておく
			int aNewLength = [mLastData length];
			if(aNewLength > 2){
				aNewLength -= 2;
			}
			[mLastData setLength:aNewLength];
			[mLastData appendBytes:(aDataTop + 1) length:(aDataLength - 1)];
			return;
		}
	}
	//さもなくば新規データを確保し、配列に追加する
	mLastData = [NSMutableData dataWithData:iData];
	[mDataArray addObject:mLastData];
}

//pushメソッドが全て終わったら、これを呼ぶこと
- (void)pushEnd
{
	NSEnumerator *aItr = [mDataArray objectEnumerator];
	NSMutableData *aItem; //一行データ
	
	while((aItem = [aItr nextObject]) != nil){
		int aLen = [aItem length]; //一行の長さ
		char *aTopP = [aItem mutableBytes]; //一行の先頭
		char *aSep1 = memchr(aTopP,':',aLen); //":"の位置を探す
		if(aSep1 != NULL){
			char *aSepE = memchr(aSep1,'\r',aLen - (aSep1 - aTopP)); //CRを探す
			if(aSepE != NULL){
				char *aSep2 = aSep1 + 1; //次の単語の始まりを探す
				while(*aSep2 == 0x20 || *aSep2 == 0x09){
					++aSep2;
				}
				if(*aSep2 != '\r'){
					NSString *aKey; //(aTopPから(aSep1-1)までがkey)
					NSMutableData *aValue; //(aSep2から(aSepE-1)までがvalue)
					
					aKey = [NSString stringWithCString:aTopP length:(aSep1 - aTopP)];	//TODO:stringWithCString:encoding:で置換
//					aKey = [NSString stringWithCString:aTopP encoding:NSASCIIStringEncoding];
					aValue = [NSMutableData dataWithBytes:aSep2 length:(aSepE - aSep2)];
					[mDataDict setObject:aValue forKey:[aKey uppercaseString]];
				}
			}
		}
	}
}

//解析結果をえる
//push,pushEndメソッドが終わったら、これを呼ぶこと
//iKey=キー,iDecodeJis=YESならISO-2022-JP処理をする,NOならしない
- (NSString *)pop:(NSString *)iKey decodeJis:(BOOL)iDecodeJis
{
	NSMutableData *aLine = [mDataDict objectForKey:iKey];
	if(aLine != nil){
		if(iDecodeJis){ //ISO-2022-JPデコードする場合
			char *aDp = [aLine mutableBytes];
			//1バイトだけ0コードを追加する
			[aLine setLength:([aLine length] + 1)];
			//BASE64デコード
			decodeBase64(aDp);
			//サイズ調整
			[aLine setLength:strlen(aDp)];
			//ISO-2022-JPデコード
			return [[[NSString alloc] initWithData:aLine encoding:NSISO2022JPStringEncoding] autorelease];
		}else{ //しない場合
			return [NSString stringWithCString:[aLine bytes] length:[aLine length]];	//TODO:stringWithCString:encoding:で置換
//			return [NSString stringWithCString:[aLine bytes] encoding:NSASCIIStringEncoding];
		}
	}

	//ここに来た場合、求める項目がない
	return NSLocalizedString(@"EMPTY_ITEM",@"");
}

@end

//BASE64デコーダーの下請け
static int table64(char iCh)
{
	if('A' <= iCh && iCh <= 'Z'){
		return iCh - 'A';
	}
	if('a' <= iCh && iCh <= 'z'){
		return iCh - 'a' + 26;
	}
	if('0' <= iCh && iCh <= '9'){
		return iCh - '0' + 52;
	}
	if(iCh == '+'){
		return 62;
	}
	if(iCh == '/'){
		return 63;
	}
	
	return -1;
}

static const char *gISO2022Head = "=?ISO-2022-JP?B?";

#define find2022head(X) strstr_touppered(X,gISO2022Head)

static int length2022head()
{
	static int aAns = 0;
	if(aAns == 0){
		aAns = strlen(gISO2022Head);
	}
	return aAns;
}

//"=?ISO-2022-JP?B?"の箇所をデコードする
//iTextTop=デコードしたいデータ('\0'で終わる)
static void decodeBase64(char *iTextTop)
{
	char *aFind;
	char *aSrc = iTextTop;
	char *aDest = iTextTop;

	//"=?ISO-2022-JP?B?"を探す
	while((aFind = find2022head(aSrc)) != NULL){
		char *aNewDest;
		int aPhase;

		//見つけた地点までの情報をコピーする
		while(aSrc < aFind){
			*aDest++ = *aSrc++;
		}

		//ここから"?="に遭遇するまでBASE64デコードする
		aSrc = aFind + length2022head();
		aNewDest = aDest;
		aPhase = 0;
		while(*aSrc != '?' && *aSrc != '\0'){
			int aDCh = table64(*aSrc++);
			if(aDCh >= 0){
				switch(aPhase % 4){
				case 0:
					aDest[0] = (aDCh << 2);
					aNewDest = aDest;
					break;
				case 1:
					aDest[0] |= (aDCh >> 4);
					aDest[1] = ((0x0f & aDCh) << 4);
					aNewDest = aDest + 1;
					break;
				case 2:
					aDest[1] |= (aDCh >> 2);
					aDest[2] = ((0x03 & aDCh) << 6);
					aNewDest = aDest + 2;
					break;
				case 3:
					aDest[2] |= aDCh;
					aDest += 3;
					aNewDest = aDest;
					break;
				}
			}else{
				//(empty)
			}
			++aPhase;
		}
		aDest = aNewDest;

		//"?="をスキップする
		if(*aSrc == '?'){
			++aSrc;
			if(*aSrc == '='){
				++aSrc;
			}
		}
	}

	//末尾までコピーする
	while(*aSrc){
		*aDest++ = *aSrc++;
	}
	*aDest = '\0';
}

// End Of File
