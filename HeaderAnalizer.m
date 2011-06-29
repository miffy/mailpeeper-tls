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

@interface HeaderAnalizer(Private)
- (NSString *)decodeExceptISO_2022_JP:(char*)strData key:(NSMutableData *)line;
- (int)decode_QuotedPrintable:(char *)t size:(int)t_size conv:(char*)s;
- (int)decode_Base64:(const char*)src src_size:(int)srclen dst:(char*)dst dst_size:(int)dstlen;
@end


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
					*(aTopP + (aSep1 - aTopP)) = '\0';	// 長さで指定できないから文字列を分断。
					aKey = [NSString stringWithCString:aTopP encoding:NSASCIIStringEncoding];
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
			
			// 先にiso-2022-jp以外の"=?utf-8?"と"=?Shift_JIS?"のデコード。
			// デコードした文字列をaLineが持つ、文字列ポインタのaDpに入れる
			NSString* rtn = [self decodeExceptISO_2022_JP:aDp key:aLine];
			// 見つかったときは、デコードした文字列を返して終わり
			if (rtn != nil)
				return rtn;
			
			//BASE64デコード
			decodeBase64(aDp);
			//サイズ調整
			[aLine setLength:strlen(aDp)];
			//ISO-2022-JPデコード
			return [[[NSString alloc] initWithData:aLine encoding:NSISO2022JPStringEncoding] autorelease];
		}else{ //しない場合
			return [NSString stringWithCString:[aLine bytes] encoding:NSASCIIStringEncoding];
		}
	}

	//ここに来た場合、求める項目がない
	return NSLocalizedString(@"EMPTY_ITEM",@"");
}



// ------------ tls add from here ------------
#include <string.h>

// "=?utf-8?"と"=?Shift_JIS?"でいいと思うけど、大文字にしてから検索する
static const char* UTF8_HEAD = "=?UTF-8?";
static const char* SJIS_HEAD = "=?SHIFT_JIS?";
static const char* ISO2022_HEAD = "=?ISO-2022-JP?";	// QPとの組み合わせがあった（amazonからの）ので、改めて実装。


// BはBASE64(RFC 3548)。QはQuoted-Printable(RFC 1521)
// =?utf-8?Q? と =?Shift_JIS?B? のほぼ二択だが、分けて実装。あとで分けて実装するの面倒なんで。
// strDataで変換する文字列と、返す文字列を両方扱うので、デコードした文字列は、読み終わったところに書き込み
- (NSString*)decodeExceptISO_2022_JP:(char*)strData key:(NSMutableData *)line
{	
	char *aFind;				// ヘッダを見つけた位置
	char *aSrc;					// 読み取り元となる文字列の位置
	char *aDst;					// 入れ込み用ポインタ
	int prefix;					// エンコーディングされてない、前後の文字数
	NSMutableString* buff = nil;	// 
	int lineLength = [line length];	// 
	
	while (1)
	{
		char encodeType;		// MIMEエンコーディング形式 'Q'がQuoted-P'B'がBase64
		char charset;			// 文字コード 'U'がUTF-8で、'S'がShiftJIS
		int length;				// デコードする文字列の長さ
		char* startPosition;	// デコード始めの位置
		
		aDst = aSrc = strData;
		if(aFind = strstr_touppered(aSrc, UTF8_HEAD))
		{
			charset = 'U';		// UTF-8
		}else
		if(aFind = strstr_touppered(aSrc, SJIS_HEAD))
		{
			charset = 'S';		// ShiftJIS			
		}else 
		if(aFind = strstr_touppered(aSrc, ISO2022_HEAD))
		{
			charset = 'I';		// ISO-2022-JP
		}else{
			return buff;		// 見つからなかった。	
		}		
		
		// ここでやっとreturn用のバッファを作る
		if(buff == nil)
			buff = [NSMutableString string];
		
		// 見つけた地点までの情報をコピーする（エンコーディングされているもの以外はみなASCIIコードと考える）
		// UTF-8(RFC 2279)は、ASCIIコードは同じコードで1バイトで、それ以外を2～6バイトの可変長
		// ShiftJISは、エスケープシーケンスなしで1バイト文字と2バイト文字を共存させ、ASCII文字はそのまま
		while(aSrc < aFind){
			*aDst++ = *aSrc++;
		}
		prefix = aSrc - strData;		// ヘッダとかの長さは入れない。エンコードされてない素のASCII文字のみ。

		if (charset == 'S') {
			aSrc += strlen(SJIS_HEAD);			
		}else if (charset == 'U') {
			aSrc += strlen(UTF8_HEAD);			
		}else if (charset == 'I') {
			aSrc += strlen(ISO2022_HEAD);			
		}
		
		encodeType = *aSrc;				// QかBが入るはず。
		encodeType = toupper(encodeType);	// 大抵、大文字だけど、小文字も対応。RFC2047 2.
		if (!(encodeType == 'Q' || encodeType == 'B'))
			return nil;					// 知らないエンコーディングならお帰り頂く
		
		// QでもBでも、"?="までなので、デコードしたい文字列と長さを得る
		aSrc += 2;						// Q?やB?より先に移動
		startPosition = aSrc;			// 始めの位置を設定(B?かQ?以降)
		length = 0;
		// "?="で終わり
		while (*aSrc) {
			if (*aSrc++ == '?') 
			{
				if (*aSrc == '=')
					break;
			}else{
				length++;				// デコードする文字列の長さ
			}
		}
		// デコードすべき文字列を別途コピーして作成
		char tmp[strlen(aDst)];
		int i;
		for(i=0; i<length; i++){
			tmp[i] = *startPosition++;	
		}
		tmp[length] = '\0';				//ヌル文字で止めないとダメ。
		
		// エンコード形式ごとにデコード
		if (encodeType == 'B') {
			[self decode_Base64:tmp src_size:length dst:aDst dst_size:strlen(aDst)];
		}else if (encodeType == 'Q') {
			[self decode_QuotedPrintable:aDst size:length conv:tmp];
		}
		// 
		aSrc++;							// そのままだと、後ろの"?="の'='の位置なので進める。
		length = prefix + strlen(aDst);
		[line setLength: length];
		
		if (charset == 'U')
		{	// UTF-8用
			[buff appendString:[[[NSString alloc] initWithData:line 
				encoding:NSUTF8StringEncoding] autorelease]];
		}
		else if(charset == 'S')
		{	// Shift_JIS用
			[buff appendString:[[[NSString alloc] initWithData:line 
				encoding:NSShiftJISStringEncoding] autorelease]];		
		}
		else if(charset == 'I')
		{
			// ISO-20220JP用
			[buff appendString:[[[NSString alloc] initWithData:line 
				encoding:NSISO2022JPStringEncoding] autorelease]];		
		}else {
			// ないときはnilを返す。普通は来ないですが。
			return nil;
		}

		// がっつり元ネタを前の方にズラして改変。
		aDst = strData;
		for (i=0; i < lineLength - length; i++)
		{
			*aDst++ = *aSrc++;
		}
	}
}
			 
#include <stdio.h>

// QuotedPrintable パクって持ってきた
// http://f4.aaa.livedoor.jp/~pointc/202/No.5092.html
- (int)decode_QuotedPrintable:(char *)t size:(int)t_size conv:(char*)s
{
	char *end = &t[t_size-1];
	for ( ; *s && t < end; s++,t++) {
		if (*s == '=') {
			sscanf(++s,"%02X",(unsigned int*)t);
			s++;
		} else {
			if(*s == '_')
				*t = ' ';	// ヘッダではアンダーバーを半角スペースにデコードする(=20の場合あり)
			else
				*t = *s;
		}
	}
	*t = '\0';
	return strlen(t);
}

// Base64 http://www.ietf.org/rfc/rfc3548.txt
// 名前が紛らわしいが、_を付けた方が新しい方
// http://d.hatena.ne.jp/ryousanngata/20101203/1291380670 からもらってきた
- (int)decode_Base64:(const char*)src src_size:(int)srclen dst:(char*)dst dst_size:(int)dstlen
{
		const unsigned char Base64num[256] = {
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x3E,0xFF,0xFF,0xFF,0x3F,
			0x34,0x35,0x36,0x37,0x38,0x39,0x3A,0x3B,0x3C,0x3D,0xFF,0xFF,0xFF,0x00,0xFF,0xFF,
			0xFF,0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,
			0x0F,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,
			0x29,0x2A,0x2B,0x2C,0x2D,0x2E,0x2F,0x30,0x31,0x32,0x33,0xFF,0xFF,0xFF,0xFF,0xFF,
			
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
			0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,
		};
		int calclength = (srclen/4*3);
		int i,j;
		if(calclength > dstlen || srclen % 4 != 0) return 0;
		
		// 本来なら(int)のキャストはいらないけど、warningを止めるために入れた
		j=0;
		for(i=0; i+3<srclen; i+=4){
			if((Base64num[(int)src[i+0]]|Base64num[(int)src[i+1]]|Base64num[(int)src[i+2]]|Base64num[(int)src[i+3]]) > 0x3F){
				return -1;
			}
			dst[j++] = Base64num[(int)src[i+0]]<<2 | Base64num[(int)src[i+1]] >> 4;
			dst[j++] = Base64num[(int)src[i+1]]<<4 | Base64num[(int)src[i+2]] >> 2;
			dst[j++] = Base64num[(int)src[i+2]]<<6 | Base64num[(int)src[i+3]];
		}
		
		if(j<dstlen) dst[j] = '\0';
		return j;	
	
#if 0
	//他のところからパクリ。読み取りにくいコードはなるべく入れたくない。
	// http://d.hatena.ne.jp/htz/20080808/1218185920 からもらってきた
	char b64[128];
	const char *w = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
	char *p = baseStr, c[4], *buff = p;
	int i = 0, j;
	
	
	/* 変換テーブルの作成 */
	for(j = 0; j < 65; j++)
		b64[w[j]] = j % 64;
	while(*p)
	{
		/* 4文字ずつ変換 */
		for(j = 0; j < 4; j++)
			c[j] = b64[*(p++)];
		for(j = 0; j < 3; j++)
			buff[i++] = c[j] << (j * 2 + 2) | c[j + 1] >> ((2 - j) * 2);
	}
	buff[i] = '\0';
#endif
}

// ------------ tls adding end ------------

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
