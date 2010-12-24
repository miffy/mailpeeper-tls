//
//  SimpleTCPClient.h
//  MailPeeper
//
//  Created by Dentom on Mon Sep 09 2002.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
	int size; //読み書きできたサイズ
	int err; //エラー値(errno)
} SimpleTCPClient_send_recv_result;

@interface SimpleTCPClient : NSObject {
	int mSocket; //ソケットハンドル
}
- (id)init;
- (void)dealloc;
- (BOOL)connectHost:(const char *)iHost port:(unsigned short)iPort;
- (SimpleTCPClient_send_recv_result)send:(const char *)iMessage;
- (SimpleTCPClient_send_recv_result)recv:(void *)iBuff size:(int)iSize;
- (void)close;

@end

// End Of File
