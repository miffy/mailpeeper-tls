//
//  STCPCReadLine.h
//  MailPeeper
//
//  Created by Dentom on Mon Sep 09 2002.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SimpleTCPClient;

typedef struct {
	SimpleTCPClient *client;   	//利用するオブジェクト
	NSTimeInterval nextDelay;  	//次の読み込みまでの遅延時間
	NSTimeInterval timeOut;	   	//タイムアウト時間
	char delim;					//デリミタ
} STCPCReadLineSetup_t;

typedef struct {
	NSData *data; //読みこんだデータ
	BOOL error;   //YESならエラー発生
} STCPCReadLine_recv_t;

#define STCPCReadLine_BuffSize 1024

@interface STCPCReadLine : NSObject {
	STCPCReadLineSetup_t mS; 		  		//準備した情報
	char mReadBuff[STCPCReadLine_BuffSize]; //リードバッファ
	int mMaxIndex;							//recv1回で読み込んだサイズ
	int mPopIndex;							//バッファから削り取ったサイズ
}

- (void)setupClient:(STCPCReadLineSetup_t *)iSetup;
- (STCPCReadLine_recv_t)recvLine;

@end

// End Of File
