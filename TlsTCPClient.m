//
//  TlsTCPClient.m
//  MailPeeper
//
//  Created by miff 2010.
//

#import "TlsTCPClient.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/types.h>
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>


#define BUF_LEN 256


@implementation TlsTCPClient

//初期化メソッド
- (id)init
{
	if((self = [super init]) != nil)
	{
		mSocket = -1;
		ssl = NULL;
		ctx = NULL;
	}
	return self;
}

//終了化メソッド
- (void)dealloc
{
	[self tlsClose];

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
	return [self tlsConnect];

//	return YES;
}


//------------- SSLに必要なところは以下 -------------
//つないで
- (BOOL)tlsConnect
{	
	int ret;
		
	SSL_load_error_strings();					//エラーメッセージを文字列で
	SSL_library_init();							//SSL/TLSの初期化
	ctx = SSL_CTX_new(TLSv1_client_method());	//プロトコル選択
	if ( ctx == NULL )
	{
		ERR_print_errors_fp(stderr);			//エラー情報の取得
		return NO;
	}
	
	ssl = SSL_new(ctx);							//SSL_CTX構造体を生成
	if ( ssl == NULL )
	{
		ERR_print_errors_fp(stderr);			
		return NO;
	}
	
	ret = SSL_set_fd(ssl, mSocket);				//ソケットとSSLの構造体を結びつけ
	if ( ret == 0 )
	{
		ERR_print_errors_fp(stderr);			
		return NO;
	}
	
	/* PRNG 初期化 */
/*	RAND_poll();								//乱数の種生成
	while ( RAND_status() == 0 )				//乱数の種の過不足チェック
	{
		unsigned short rand_ret = rand() % 65536;
		RAND_seed(&rand_ret, sizeof(rand_ret));	//乱数の大きさが小さい場合追加
	}
*/	
	/* SSL で接続 */
	ret = SSL_connect(ssl);						//サーバとハンドシェイク
	
	ERR_remove_state(0);
	
	if ( ret != 1 )
	{
		ERR_print_errors_fp(stderr);			
		return NO;
	}
	
	
	return YES;
}


//メッセージ送って
- (TlsTCPClient_send_recv_result)send:(const char *)iMessage
{
	TlsTCPClient_send_recv_result aRes = { -1,0 };
	aRes.size = SSL_write(ssl, iMessage, strlen(iMessage));   //リクエスト送信 
	if(aRes.size < 0)
		aRes.err = errno;	
	if ( aRes.size < 1 )
		ERR_print_errors_fp(stderr);
	
//	ERR_remove_state(0);	// メモリリーク対策
	return aRes;
}


//メッセージ受けて
- (TlsTCPClient_send_recv_result)recv:(void *)iBuff size:(int)iSize
{
	TlsTCPClient_send_recv_result aRes = { -1,0 };
	aRes.size = SSL_read(ssl, iBuff, iSize-1);
	
	if(aRes.size < 0)
		aRes.err = errno;
	if ( aRes.size < 1 )
		ERR_print_errors_fp(stderr);
//	ERR_remove_state(0);	// メモリリーク対策
	return aRes;
}

						 
//ソケットとか閉じる終了作業
- (void)tlsClose
{	
	int ret;
	
	SSL_CTX_free(ctx);					//SSL_CTX_new()で確保した領域解放
	ERR_free_strings();					//SSL_load_error_strings()で確保した領域解放	
//	EVP_cleanup();						// メモリリーク対策
	CRYPTO_cleanup_all_ex_data();		// メモリリーク対策
	ERR_remove_state(0);				// メモリリーク対策
//	ENGINE_cleanup();					// メモリリーク対策
//	CONF_modules_unload(1);				// メモリリーク対策
	
	if (ssl != NULL) 
		ret = SSL_shutdown(ssl);		//TLSのコネクションを切る
	else 
		return;

	SSL_free(ssl);						//SSL_new()で確保した領域解放
//	ERR_remove_state(0);				// メモリリーク対策
	if(mSocket >= 0)
	{
		close(mSocket);
		mSocket = -1;
	}
	
	
	if ( ret != 1 )
	{
		ERR_print_errors_fp(stderr);	
		return;
	}

}


//ソケットを閉じる(tlsを使う前用)
- (void)close
{
	if(mSocket >= 0){
		close(mSocket);
		mSocket = -1;
	}
}


@end

// End Of File