//
//  SimpleTCPClient.m
//  MailPeeper
//
//  Created by Dentom on Mon Sep 09 2002.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import "SimpleTCPClient.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

@implementation SimpleTCPClient

//初期化メソッド
- (id)init
{
	if((self = [super init]) != nil){
		mSocket = -1;
	}
	return self;
}

//終了化メソッド
- (void)dealloc
{
	[self close];

	[super dealloc];
}

//ホストに接続する
//iHost=ホスト名,iPort=ポート番号
//戻り値=YESなら接続成功,NOなら失敗
- (BOOL)connectHost:(const char *)iHost port:(unsigned short)iPort
{
	int aSocket;
	struct hostent *aHostent;
	struct sockaddr_in aDest;

	//接続先のアドレス解決
	aHostent = gethostbyname(iHost);
	if(aHostent == NULL){
		return NO;
	}

	//ソケットを確保
	aSocket = socket(AF_INET,SOCK_STREAM,0);
	if(aSocket < 0){
		return NO;
	}

	//接続の準備
	[self close];
	memset(&aDest,0,sizeof(aDest));
	aDest.sin_family = AF_INET;
	aDest.sin_port = htons(iPort);
	memcpy(&aDest.sin_addr.s_addr,aHostent->h_addr_list[0],aHostent->h_length);
	
	//接続開始
	if(connect(aSocket,(struct sockaddr *)&aDest,sizeof(aDest)) == 0){
		//成功時
		mSocket = aSocket;
	}else{
		//失敗時
		close(aSocket);
		return NO;
	}

	return YES;
}

//メッセージを送る
//iMessage=送るメッセージ(ASCIZ文字列)
//戻り値.size=送ったサイズ(sendの戻り値),戻り値.err=エラー値(errno)
- (SimpleTCPClient_send_recv_result)send:(const char *)iMessage
{
	SimpleTCPClient_send_recv_result aRes = { -1,0 };
	if(mSocket >= 0){
		aRes.size = send(mSocket,iMessage,strlen(iMessage),0);
		if(aRes.size < 0){
			aRes.err = errno;
		}
	}
	return aRes;
}

//データを受信する
//iBuff=受信バッファ,iSize=バッファのサイズ
//戻り値.size=受信サイズ(recvの戻り値),戻り値.err=エラー値(errno)
- (SimpleTCPClient_send_recv_result)recv:(void *)iBuff size:(int)iSize
{
	SimpleTCPClient_send_recv_result aRes = { -1,0 };
	if(mSocket >= 0){
		aRes.size = recv(mSocket,iBuff,iSize,MSG_DONTWAIT);
		if(aRes.size < 0){
			aRes.err = errno;
		}
	}
	return aRes;
}

//ソケットを閉じる
- (void)close
{
	if(mSocket >= 0){
		close(mSocket);
		mSocket = -1;
	}
}

@end

// End Of File
