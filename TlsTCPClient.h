//
//  TlsTCPClient.h
//  MailPeeper
//
//  Created by miff 2010.
//

#import <Foundation/Foundation.h>

#if 0
#include <openssl/crypto.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <openssl/rand.h>
#else

#define OPENSSL_NO_LHASH
#include "openssl/crypto.h"
#include "openssl/ssl.h"
#include "openssl/err.h"
#include "openssl/rand.h"
#endif

typedef struct {
	int size; //読み書きできたサイズ
	int err; //エラー値(errno)
} TlsTCPClient_send_recv_result;

@interface TlsTCPClient : NSObject {
	int mSocket;	//ソケットハンドル
	SSL *ssl;		//SSLなソケット
	SSL_CTX *ctx;	//各種SSLなオブジェクト
}
- (id)init;
- (void)dealloc;
- (BOOL)connectHost:(const char *)iHost port:(unsigned short)iPort;
- (TlsTCPClient_send_recv_result)send:(const char *)iMessage;
- (TlsTCPClient_send_recv_result)recv:(void *)iBuff size:(int)iSize;
- (void)close;
- (BOOL)tlsConnect;
//- (TlsTCPClient_send_recv_result)tlsSend:(const char *)iMessage;
//- (TlsTCPClient_send_recv_result)tlsRecv:(void *)iBuff size:(int)iSize;
- (void)tlsClose;

@end

// End Of File
