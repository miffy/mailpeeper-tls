//
//  WorkerThread.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/14-10/14.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppController;
@class PrefController;
@class STCPCReadLine;
@class SimpleTCPClient;
@class AccountItem;
@class PeepedItem;
@class TlsTCPClient;

@class TlsReadLine;


@interface WorkerThread : NSObject {
	AppController *mAppController;		//アプリケーションコントローラー
	PrefController *mPrefController;	//Prefコントローラー(runメソッド呼び出し以降に有効になる)

	BOOL mErr;							//YESならエラー発生
	BOOL mUserPause;					//YESならユーザーからの中断
	int mRecvMailCnt;					//受信メールの個数
	int mNewMailCnt;					//新規メールの個数
	int mRemoveMailCnt;					//削除メールの個数

	AccountItem *mAccountItem;			//アカウント情報
	SimpleTCPClient *mSocket;			//ソケットオブジェクト
	STCPCReadLine *mReadLine;			//行読み取りオブジェクト
	
	TlsTCPClient *mTlsSocket;			//ソケットオブジェクト（Tls用）
	TlsReadLine *mTlsReadLine;			//行読み取りオブジェクト（Tls用）
	
	NSMutableArray *mRemoveItemArray;	//削除アイテムの一時保存用
}
- (id)initWithAppController:(AppController *)iAppController;
- (void)run:(NSMutableArray *)iRemoveItemArray;
- (void)userAbort;

@end

// End Of File
