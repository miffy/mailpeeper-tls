//
//  TlsReadLine.h
//  MailPeeper
//
//  Created in 2010 by miff
//

#import <Foundation/Foundation.h>

@class TlsTCPClient;

typedef struct {
	TlsTCPClient *client;   	//利用するオブジェクト
	NSTimeInterval nextDelay;  	//次の読み込みまでの遅延時間
	NSTimeInterval timeOut;	   	//タイムアウト時間
	char delim;					//デリミタ
} TlsReadLineSetup_t;

typedef struct {
	NSData *data; //読みこんだデータ
	BOOL error;   //YESならエラー発生
} TlsReadLine_recv_t;

#define TlsReadLine_BuffSize 1024

@interface TlsReadLine : NSObject {
	TlsReadLineSetup_t mS;					//準備した情報
	char mReadBuff[TlsReadLine_BuffSize];	//リードバッファ
	int mMaxIndex;							//recv1回で読み込んだサイズ
	int mPopIndex;							//バッファから削り取ったサイズ
}

- (void)setupClient:(TlsReadLineSetup_t *)iSetup;
- (TlsReadLine_recv_t)recvLine;

@end

// End Of File
