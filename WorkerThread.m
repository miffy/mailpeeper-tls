//
//  WorkerThread.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/14-11/10.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "WorkerThread.h"
#import "AppController.h"
#import "AccountItem.h"
#import "PrefController.h"
#import "STCPCReadLine.h"
#import "SimpleTCPClient.h"
#import "UIDLHelpItem.h"
#import "PeepedItem.h"
#import "Misc.h"

#import "TlsReadLine.h"
#import "TlsTCPClient.h"

@interface WorkerThread(Private)
- (void)mainThread:(id)iArg;
- (void)throwException:(NSString *)iMsg error:(BOOL)iErr;
- (void)ifErr:(BOOL)iCond throwException:(NSString *)iMsg;
- (void)checkKill;
- (void)checkServerOK:(NSString *)iNGmessage;

- (void)tlsCheckServerOK:(NSString *)iNGmessage;
- (void)tlsProcAccount;
- (void)tlsProcMail;

- (void)removePeepedItem: (NSMutableArray*) aUIDLHelpItemArray;

@end

@implementation WorkerThread

//初期化メソッド
- (id)initWithAppController:(AppController *)iAppController
{
	if((self = [super init]) != nil){
		mAppController = iAppController;
	}
	return self;
}

//スレッドを走行させる
//iRemoveItemArray=nilならメール収集,nilでないなら削除すべきメールアイテム配列
- (void)run:(NSMutableArray *)iRemoveItemArray
{
	//NSLog(@"WorkerThread.run");

	mErr = mUserPause = NO;
	mRemoveItemArray = [iRemoveItemArray retain];
	//Prefコントローラーをえる
	mPrefController = [mAppController prefController];
	//スレッドを起動する
	[NSThread detachNewThreadSelector:@selector(mainThread:) toTarget:self withObject:self];
}

//スレッドの中止を要求する
- (void)userAbort
{
	mUserPause = YES;
}

@end

@implementation WorkerThread(Private)

//受信したUIDL情報が新規メールであるかを確認する
//戻り値=nilなら新規メール,さもなくば同じメールを保持するアイテムへのポインタ
- (PeepedItem *)checkNewUIDL:(UIDLHelpItem *)iUIDLHelpItem
{
	NSEnumerator *aItr = [mAppController peepedItemIterator];
	PeepedItem *aPeepedItem;
	
	while((aPeepedItem = [aItr nextObject]) != nil){
		if([[aPeepedItem uid] isEqualToString:[iUIDLHelpItem uid]] && ([aPeepedItem accountID] == [iUIDLHelpItem accountID])){
			return aPeepedItem;
		}
	}
	return nil;
}

//TOPコマンドを発行して情報を集める
//iItem=発行の対象を保持しているオブジェクト,iPeep=記録オブジェクト
- (void)sendTOPcommand:(UIDLHelpItem *)iItem recTo:(PeepedItem *)iPeep
{
	NSString *aString;
	NSString *aServerErrMsg;

	//NSLog(@"WorkerThread.sendTOPcommand:%d",[iItem number]);
	
	//TOPコマンドの発行
	aString = [NSString stringWithFormat:@"TOP %d 0\r\n",[iItem number]];
	[mSocket send:[aString cStringUsingEncoding:NSASCIIStringEncoding]];
	[self checkKill];

	//サーバーからの+OKを確認する
	aServerErrMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PROC_NG",@""),[mAccountItem accountName]];
	[self checkServerOK:aServerErrMsg];

	//"."が来るまでサーバーからの情報をえる
	for(;;){
		//1行を読み取る
		STCPCReadLine_recv_t aServRes = [mReadLine recvLine];
		[self ifErr:aServRes.error throwException:aServerErrMsg]; //エラーなら中断
		[aServRes.data autorelease];
		aString = [Misc dataToString:aServRes.data];
		if([aString isEqualToString:@".\r\n"]){
			return;
		}
		//読み取った1行を記録する
		[iPeep appendTOPdata:aServRes.data];
	}
}

- (void)tlsSendTOPcommand:(UIDLHelpItem *)iItem recTo:(PeepedItem *)iPeep
{
	NSString *aString;
	NSString *aServerErrMsg;
	
	//NSLog(@"WorkerThread.sendTOPcommand:%d",[iItem number]);
	
	//TOPコマンドの発行
	aString = [NSString stringWithFormat:@"TOP %d 0\r\n",[iItem number]];
	[mTlsSocket send:[aString cStringUsingEncoding:NSASCIIStringEncoding]];
	[self checkKill];
	
	//サーバーからの+OKを確認する
	aServerErrMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PROC_NG",@""),[mAccountItem accountName]];
	[self tlsCheckServerOK:aServerErrMsg];
	
	//"."が来るまでサーバーからの情報をえる
	for(;;){
		//1行を読み取る
		TlsReadLine_recv_t aServRes = [mTlsReadLine recvLine];
		[self ifErr:aServRes.error throwException:aServerErrMsg]; //エラーなら中断
		[aServRes.data autorelease];
		aString = [Misc dataToString:aServRes.data];
		if([aString isEqualToString:@".\r\n"]){
			return;
		}
		//読み取った1行を記録する
		[iPeep appendTOPdata:aServRes.data];
	}
}

//LISTコマンドを発行して情報を集める
//iItem=発行の対象を保持しているオブジェクト,iPeep=記録オブジェクト
- (void)sendLISTcommand:(UIDLHelpItem *)iItem recTo:(PeepedItem *)iPeep
{
	STCPCReadLine_recv_t aServRes;
	NSString *aMsg;
	NSScanner *aScanner;
	int aSize;

	//LISTコマンドの発行
	aMsg = [NSString stringWithFormat:@"LIST %d\r\n",[iItem number]];
	[mSocket send:[aMsg cStringUsingEncoding:NSASCIIStringEncoding]];
	[self checkKill];

	//1行を読み取る
	aServRes = [mReadLine recvLine];
	if(!aServRes.error){ //エラーでないなら
		[aServRes.data autorelease];
	
		//(読みとったデータが "+OK 番号 受信サイズ" である前提で処理を続行する)
		aMsg = [Misc dataToString:aServRes.data];
		aScanner = [NSScanner scannerWithString:aMsg];
		if([aScanner scanString:@"+OK" intoString:nil] && [aScanner scanInt:&aSize] && [aScanner scanInt:&aSize]){
			[iPeep setMailSize:aSize];
			return;
		}
	}

	//ここに来るならエラー
	aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PROC_NG",@""),[mAccountItem accountName]];
	[self throwException:aMsg error:YES];
}

- (void)tlsSendLISTcommand:(UIDLHelpItem *)iItem recTo:(PeepedItem *)iPeep
{
	TlsReadLine_recv_t aServRes;
	NSString *aMsg;
	NSScanner *aScanner;
	int aSize;
	
	//LISTコマンドの発行
	aMsg = [NSString stringWithFormat:@"LIST %d\r\n",[iItem number]];
	[mTlsSocket send:[aMsg cStringUsingEncoding:NSASCIIStringEncoding]];
	[self checkKill];
	
	//1行を読み取る
	aServRes = [mTlsReadLine recvLine];
	if(!aServRes.error){ //エラーでないなら
		[aServRes.data autorelease];
		
		//(読みとったデータが "+OK 番号 受信サイズ" である前提で処理を続行する)
		aMsg = [Misc dataToString:aServRes.data];
		aScanner = [NSScanner scannerWithString:aMsg];
		if([aScanner scanString:@"+OK" intoString:nil] && [aScanner scanInt:&aSize] && [aScanner scanInt:&aSize]){
			[iPeep setMailSize:aSize];
			return;
		}
	}
	
	//ここに来るならエラー
	aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PROC_NG",@""),[mAccountItem accountName]];
	[self throwException:aMsg error:YES];
}


//受信メールの確認 または メールの削除
- (void)procMail
{
	NSMutableArray *aUIDLHelpItemArray;
	UIDLHelpItem *aUIDLHelpItem;
	STCPCReadLine_recv_t aServRes;
	NSString *aServerErrMsg;
	BOOL aLoop;
	NSEnumerator *aUIDLHelpItemItr;
	PeepedItem *aPeepedItem;

	NSLog(@"WorkerThread.procMail");

	//UIDLコマンドの発行
	[mSocket send:"UIDL\r\n"];
	[self checkKill];

	//サーバーからの+OKを確認する
	aServerErrMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PROC_NG",@""),[mAccountItem accountName]];
	[self checkServerOK:aServerErrMsg];
	[self checkKill];

	//UIDL情報を収集する
	aUIDLHelpItemArray = [NSMutableArray array];
	for(aLoop = YES; aLoop; ){
		aServRes = [mReadLine recvLine];
		[self ifErr:aServRes.error throwException:aServerErrMsg]; //エラー検出時に例外

		//UIDLアイテムの生成
		aUIDLHelpItem = [UIDLHelpItem createItem:[aServRes.data autorelease] accountID:[mAccountItem accountID]];
		[self ifErr:[aUIDLHelpItem error] throwException:aServerErrMsg]; //エラー検出時に例外
		if([aUIDLHelpItem finish]){ //情報の集結を検出時
			aLoop = NO;
		}else{ //通常のUIDL情報をえた時
			++mRecvMailCnt; //受信メール数を増やす
			//新規のメールであるかを確認する
			if((aPeepedItem = [self checkNewUIDL:aUIDLHelpItem]) == nil){ //新規のメールである場合
				if(mRemoveItemArray == nil){ //メール受信の場合
					++mNewMailCnt; //新規メール数を増やす
					[aUIDLHelpItem setNewMailNo:mNewMailCnt];
					[aUIDLHelpItemArray addObject:aUIDLHelpItem]; //登録する
				}
			}else{ //すでに存在するメールである場合
				if(mRemoveItemArray == nil){ //メール受信の場合
					[aPeepedItem setSaveFlag:YES]; //保存フラグを立てる
				}else{ //メール削除の場合
					[aUIDLHelpItemArray addObject:aUIDLHelpItem]; //登録する
				}
			}
		}
		[self checkKill];
	}
	

	if(mRemoveItemArray == nil){ //メール受信の場合
		int aTotal = [aUIDLHelpItemArray count]; //このアカウントでの新規メールの総数
		int aRecv = 0; //このアカウントでの処理メール数カウント
		//新規メールの情報をサーバーから取得する
		aUIDLHelpItemItr = [aUIDLHelpItemArray objectEnumerator];
		while((aUIDLHelpItem = [aUIDLHelpItemItr nextObject]) != nil){
			//処理メール数をステータス表示
			NSString *aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_REPORT_COUNT",@""),
														[mAccountItem accountName],
														aTotal,
														++aRecv];
			[mAppController postStatusBlack:aMsg];

			//新規メール情報保持オブジェクトの生成
			aPeepedItem = [[[PeepedItem alloc] init] autorelease];
			[aPeepedItem setAccountID:[mAccountItem accountID]]; //アカウントIDの設定
			[aPeepedItem setSaveFlag:YES]; //保存フラグを立てる
			[aPeepedItem setNewMailFlag:YES]; //新規メール印を立てる
			[aPeepedItem setUID:[aUIDLHelpItem uid]]; //UIDの設定
	
			//LISTコマンドをサーバーに送りサイズ情報をえる
			[self sendLISTcommand:aUIDLHelpItem recTo:aPeepedItem];
			[self checkKill];
	
			//TOPコマンドをサーバーに送りヘッダー情報をえる
			[self sendTOPcommand:aUIDLHelpItem recTo:aPeepedItem];
			[self checkKill];
	
			//新規メール情報を記録する
			[aPeepedItem analizeHeader]; //ヘッダ情報の解釈を行う
			[mAppController postNewMail:aPeepedItem no:[aUIDLHelpItem newMailNo]];
		}
	}else{ //メール削除の場合
		int aIndex;
		for(aIndex = [mRemoveItemArray count] - 1; aIndex >= 0; aIndex--){
			aPeepedItem = [mRemoveItemArray objectAtIndex:aIndex];
			aUIDLHelpItemItr = [aUIDLHelpItemArray objectEnumerator];
			while((aUIDLHelpItem = [aUIDLHelpItemItr nextObject]) != nil){
				//削除対象を探す
				if([[aUIDLHelpItem uid] isEqualToString:[aPeepedItem uid]] && [aUIDLHelpItem accountID] == [aPeepedItem accountID]){
					NSString *aString;

					//DELEコマンドの発行
					aString = [NSString stringWithFormat:@"DELE %d\r\n",[aUIDLHelpItem number]];
					[mSocket send:[aString cStringUsingEncoding:NSASCIIStringEncoding]];
					[self checkKill];

					//サーバーからの+OKを確認する
					[self checkServerOK:aServerErrMsg];
					[self checkKill];

					++mRemoveMailCnt;
					//保存フラグを落とす
					[aPeepedItem setSaveFlag:NO];
					//登録を抹消する
					[mRemoveItemArray removeObjectAtIndex:aIndex];
				}
			}
		}
	}
	
	[self removePeepedItem: aUIDLHelpItemArray];
	
}




// ここいらへんで、以前あったけど消えているメールの情報を解放
- (void)removePeepedItem: (NSMutableArray*) aUIDLHelpItemArray
{
	NSEnumerator *aItr = [mAppController peepedItemIterator];	
	PeepedItem* aPeepedItem;
	while((aPeepedItem = [aItr nextObject]) != nil)
	{
		PeepedItem *aUIDLItem;
		NSEnumerator* aUIDLHelpItemItr = [aUIDLHelpItemArray objectEnumerator];
		while((aUIDLItem = [aUIDLHelpItemItr nextObject]) != nil)
		{
			if((![[aPeepedItem uid] isEqualToString:[aUIDLItem uid]] && 
				 ([aPeepedItem accountID] == [aUIDLItem accountID])))
			{
				// peepedItemにあって、helpItemにないときは、peepedItemの方を解放
				[[mAppController peepedItemArray] removeObject:aPeepedItem];
			}
		}
	}
}





//受信メールの確認 または メールの削除(TLS用)
- (void)tlsProcMail
{
	NSMutableArray *aUIDLHelpItemArray;
	UIDLHelpItem *aUIDLHelpItem;
	TlsReadLine_recv_t aServRes;
	NSString *aServerErrMsg;
	BOOL aLoop;
	NSEnumerator *aUIDLHelpItemItr;
	PeepedItem *aPeepedItem;
	
	//NSLog(@"WorkerThread.procMail");
	
	//UIDLコマンドの発行
	[mTlsSocket send:"UIDL\r\n"];
	[self checkKill];
	
	//サーバーからの+OKを確認する
	aServerErrMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PROC_NG",@""),[mAccountItem accountName]];
	[self tlsCheckServerOK:aServerErrMsg];
	[self checkKill];
	
	//UIDL情報を収集する
	aUIDLHelpItemArray = [NSMutableArray array];
	for(aLoop = YES; aLoop; ){
		aServRes = [mTlsReadLine recvLine];
		[self ifErr:aServRes.error throwException:aServerErrMsg]; //エラー検出時に例外
		
		//UIDLアイテムの生成
		aUIDLHelpItem = [UIDLHelpItem createItem:[aServRes.data autorelease] accountID:[mAccountItem accountID]];
		[self ifErr:[aUIDLHelpItem error] throwException:aServerErrMsg]; //エラー検出時に例外
		if([aUIDLHelpItem finish]){ //情報の集結を検出時
			aLoop = NO;
		}else{ //通常のUIDL情報をえた時
			++mRecvMailCnt; //受信メール数を増やす
			//新規のメールであるかを確認する
			if((aPeepedItem = [self checkNewUIDL:aUIDLHelpItem]) == nil){ //新規のメールである場合
				if(mRemoveItemArray == nil){ //メール受信の場合
					++mNewMailCnt; //新規メール数を増やす
					[aUIDLHelpItem setNewMailNo:mNewMailCnt];
					[aUIDLHelpItemArray addObject:aUIDLHelpItem]; //登録する
				}
			}else{ //すでに存在するメールである場合
				if(mRemoveItemArray == nil){ //メール受信の場合
					[aPeepedItem setSaveFlag:YES]; //保存フラグを立てる
				}else{ //メール削除の場合
					[aUIDLHelpItemArray addObject:aUIDLHelpItem]; //登録する
				}
			}
		}
		[self checkKill];
	}
	
	if(mRemoveItemArray == nil){ //メール受信の場合
		int aTotal = [aUIDLHelpItemArray count]; //このアカウントでの新規メールの総数
		int aRecv = 0; //このアカウントでの処理メール数カウント
		//新規メールの情報をサーバーから取得する
		aUIDLHelpItemItr = [aUIDLHelpItemArray objectEnumerator];
		while((aUIDLHelpItem = [aUIDLHelpItemItr nextObject]) != nil){
			//処理メール数をステータス表示
			NSString *aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_REPORT_COUNT",@""),
							  [mAccountItem accountName],
							  aTotal,
							  ++aRecv];
			[mAppController postStatusBlack:aMsg];
			
			//新規メール情報保持オブジェクトの生成
			aPeepedItem = [[[PeepedItem alloc] init] autorelease];
			[aPeepedItem setAccountID:[mAccountItem accountID]]; //アカウントIDの設定
			[aPeepedItem setSaveFlag:YES]; //保存フラグを立てる
			[aPeepedItem setNewMailFlag:YES]; //新規メール印を立てる
			[aPeepedItem setUID:[aUIDLHelpItem uid]]; //UIDの設定
			
			//LISTコマンドをサーバーに送りサイズ情報をえる
			[self tlsSendLISTcommand:aUIDLHelpItem recTo:aPeepedItem];
			[self checkKill];
			
			//TOPコマンドをサーバーに送りヘッダー情報をえる
			[self tlsSendTOPcommand:aUIDLHelpItem recTo:aPeepedItem];
			[self checkKill];
			
			//新規メール情報を記録する
			[aPeepedItem analizeHeader]; //ヘッダ情報の解釈を行う
			[mAppController postNewMail:aPeepedItem no:[aUIDLHelpItem newMailNo]];
		}
	}else{ //メール削除の場合
		int aIndex;
		for(aIndex = [mRemoveItemArray count] - 1; aIndex >= 0; aIndex--){
			aPeepedItem = [mRemoveItemArray objectAtIndex:aIndex];
			aUIDLHelpItemItr = [aUIDLHelpItemArray objectEnumerator];
			while((aUIDLHelpItem = [aUIDLHelpItemItr nextObject]) != nil){
				//削除対象を探す
				if([[aUIDLHelpItem uid] isEqualToString:[aPeepedItem uid]] && [aUIDLHelpItem accountID] == [aPeepedItem accountID]){
					NSString *aString;
					
					//DELEコマンドの発行
					aString = [NSString stringWithFormat:@"DELE %d\r\n",[aUIDLHelpItem number]];
					[mSocket send:[aString cStringUsingEncoding:NSASCIIStringEncoding]];
					[self checkKill];
					
					//サーバーからの+OKを確認する
					[self checkServerOK:aServerErrMsg];
					[self checkKill];
					
					++mRemoveMailCnt;
					//保存フラグを落とす
					[aPeepedItem setSaveFlag:NO];
					//登録を抹消する
					[mRemoveItemArray removeObjectAtIndex:aIndex];
				}
			}
		}
	}
	//[self removePeepedItem: aUIDLHelpItemArray];
}


//ユーザーからの中断を確認する
- (void)checkKill
{
	if(mUserPause){
		[self throwException:NSLocalizedString(@"THSTAT_USER_KILL",@"") error:NO];
	}
}

//STATコマンドの結果を調べる
//戻り値=YESなら受信メールあり,NOなら受信メールなしかエラー発生
- (BOOL)checkSTATresult
{
	STCPCReadLine_recv_t aServRes;
	NSString *aString;
	NSScanner *aScanner;
	int aRecvCnt;

	//1行を読み取る
	aServRes = [mReadLine recvLine];
	if(aServRes.error){ //エラー検出時
		return NO;
	}
	[aServRes.data autorelease];

	//(読みとったデータが "+OK 受信数 受信サイズ" である前提で処理を続行する)
	aString = [Misc dataToString:aServRes.data];
	aScanner = [NSScanner scannerWithString:aString];
	
	//"+OK"でないなら戻る
	if(![aScanner scanString:@"+OK" intoString:nil]){
		return NO;
	}

	//受信数をえる
	if(![aScanner scanInt:&aRecvCnt]){
		return NO;
	}

	return (aRecvCnt > 0);
}

//STATコマンドの結果を調べる
//戻り値=YESなら受信メールあり,NOなら受信メールなしかエラー発生
- (BOOL)tlsCheckSTATresult
{
	TlsReadLine_recv_t aServRes;
	NSString *aString;
	NSScanner *aScanner;
	int aRecvCnt;
	
	//1行を読み取る
	aServRes = [mTlsReadLine recvLine];
	if(aServRes.error){ //エラー検出時
		return NO;
	}
	[aServRes.data autorelease];
	
	//(読みとったデータが "+OK 受信数 受信サイズ" である前提で処理を続行する)
	aString = [Misc dataToString:aServRes.data];
	aScanner = [NSScanner scannerWithString:aString];
	
	//"+OK"でないなら戻る
	if(![aScanner scanString:@"+OK" intoString:nil]){
		return NO;
	}
	
	//受信数をえる
	if(![aScanner scanInt:&aRecvCnt]){
		return NO;
	}
	
	return (aRecvCnt > 0);
}


//サーバーからの+OKを確認する
//iNGmessage=NGだったときにステータス表示したいメッセージ
- (void)checkServerOK:(NSString *)iNGmessage
{
	STCPCReadLine_recv_t aServRes;

	//1行を読み取る
	aServRes = [mReadLine recvLine];
	[self ifErr:aServRes.error throwException:iNGmessage]; //エラー検出時に例外
	[aServRes.data autorelease];
	//データがないか、3byteより小さいならNG
	[self ifErr:(aServRes.data == nil || [aServRes.data length] < 3) throwException:iNGmessage];
	//"+OK"でないならNG
	[self ifErr:(memcmp([aServRes.data bytes],"+OK",3) != 0) throwException:iNGmessage];
}

- (void)tlsCheckServerOK:(NSString *)iNGmessage
{
	TlsReadLine_recv_t aServRes;
	
	//1行を読み取る
	aServRes = [mTlsReadLine recvLine];
	[self ifErr:aServRes.error throwException:iNGmessage]; //エラー検出時に例外
	[aServRes.data autorelease];
	//データがないか、3byteより小さいならNG
	[self ifErr:(aServRes.data == nil || [aServRes.data length] < 3) throwException:iNGmessage];
	//"+OK"でないならNG
	[self ifErr:(memcmp([aServRes.data bytes],"+OK",3) != 0) throwException:iNGmessage];
}

//1つのアカウントの処理
- (void)procAccount
{
	NSAutoreleasePool *aPool = [[NSAutoreleasePool alloc] init];
	STCPCReadLineSetup_t aSetup;
	NSString *aMsg;
	
	//あらかじめソケットオブジェクト,行読み取りオブジェクトを消去しておく
	mSocket = nil;			
	mReadLine = nil;

	NS_DURING
		//アカウント名をステータス表示
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_ACCOUNT",@""),[mAccountItem accountName]];
		[mAppController postStatusBlack:aMsg];

		//ソケットの確保
		mSocket = [[SimpleTCPClient alloc] init];
		//ホストへ接続開始
		if([mSocket connectHost:[[mAccountItem pop3Server] cStringUsingEncoding:NSASCIIStringEncoding] port:[mAccountItem portNo]]){
			//接続したことをステータス表示する
			aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_CONNECT",@""),[mAccountItem accountName]];
			[mAppController postStatusBlack:aMsg];
		}else{
			//接続できなかったら中断
			aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_CONNECT_NG",@""),[mAccountItem accountName]];
			[self throwException:aMsg error:YES];
		}
		[self checkKill];

		//行読み取りオブジェクトの確保と準備
		mReadLine = [[STCPCReadLine alloc] init];
		aSetup.client = mSocket;   	//利用するオブジェクト
		aSetup.nextDelay = 0.1;  	//次の読み込みまでの遅延時間
		aSetup.timeOut = 60;	   	//タイムアウト時間
		aSetup.delim = 0x0a;		//デリミタ
		[mReadLine setupClient:&aSetup];

		//サーバーからの+OKを確認する
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_CONNECT_NG",@""),[mAccountItem accountName]];
		[self checkServerOK:aMsg];
		[self checkKill];

		//USERコマンドの発行
		aMsg = [NSString stringWithFormat:@"USER %@\r\n",[mAccountItem userName]];
		[mSocket send:[aMsg cStringUsingEncoding:NSASCIIStringEncoding]];
		[self checkKill];

		//サーバーからの+OKを確認する
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_USER_NG",@""),[mAccountItem accountName]];
		[self checkServerOK:aMsg];
		[self checkKill];

		//PASSコマンドの発行
		aMsg = [NSString stringWithFormat:@"PASS %@\r\n",[mAccountItem passWord]];
		[mSocket send:[aMsg cStringUsingEncoding:NSASCIIStringEncoding]];
		[self checkKill];

		//サーバーからの+OKを確認する
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PASS_NG",@""),[mAccountItem accountName]];
		[self checkServerOK:aMsg];
		[self checkKill];

		if(mRemoveItemArray == nil){ //メール受信の場合
			//STATコマンドの発行
			[mSocket send:"STAT\r\n"];
			[self checkKill];
	
			//STATコマンドの結果を確認する
			if([self checkSTATresult]){
				//受信しているメールがあるなら、その確認へ
				[self procMail];
			}
			// STATで何もなかったら、そのアカウントの元々あったメールデータを削除する - tls
			else
			{
				NSEnumerator *aItr = [mAppController peepedItemIterator];	
				PeepedItem* aPeepedItem;
				while((aPeepedItem = [aItr nextObject]) != nil)
				{
					if([aPeepedItem accountID] == [mAccountItem accountID])
						[[mAppController peepedItemArray] removeObject:aPeepedItem];
						//[aPeepedItem release];	//これで消すとtlsの方でエラーが出てた。
				}
			}
		}else{ //メール削除の場合
			//削除処理へ
			[self procMail];
		}
		
		//QUITコマンドの発行
		[mSocket send:"QUIT\r\n"];

	NS_HANDLER
		[mAppController postStatusRed:[localException reason]]; //例外の理由をステータス表示
	NS_ENDHANDLER

	//ソケットオブジェクト,行読み取りオブジェクトを解放する
	[mReadLine release];
	[mSocket release];

	[aPool release];
}


//1つのアカウントの処理(TLS用) - Tls関係はなるべく隠蔽する
- (void)tlsProcAccount
{
	NSAutoreleasePool *aPool = [[NSAutoreleasePool alloc] init];
	TlsReadLineSetup_t aSetup;
	NSString *aMsg;
	
	//あらかじめソケットオブジェクト,行読み取りオブジェクトを消去しておく
//	mSocket = nil;
	mReadLine = nil;
	mTlsSocket = nil;
	
	NS_DURING
	//アカウント名をステータス表示
	aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_ACCOUNT",@""),[mAccountItem accountName]];
	[mAppController postStatusBlack:aMsg];
	
	//ソケットの確保
	mTlsSocket = [[TlsTCPClient alloc] init];
	//ホストへ接続開始
	if([mTlsSocket connectHost:[[mAccountItem pop3Server] cStringUsingEncoding:NSASCIIStringEncoding] port:[mAccountItem portNo]]){
		//接続したことをステータス表示する
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_CONNECT",@""),[mAccountItem accountName]];
		[mAppController postStatusBlack:aMsg];
	}else{
		//接続できなかったら中断
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_CONNECT_NG",@""),[mAccountItem accountName]];
		[self throwException:aMsg error:YES];
	}
	[self checkKill];
	
	//行読み取りオブジェクトの確保と準備
	mTlsReadLine = [[TlsReadLine alloc] init];
	aSetup.client = mTlsSocket;	//利用するオブジェクト
	aSetup.nextDelay = 0.1;  	//次の読み込みまでの遅延時間
	aSetup.timeOut = 20;	   	//タイムアウト時間（短くした）
	aSetup.delim = 0x0a;		//デリミタ
	[mTlsReadLine setupClient:&aSetup];
	
	//サーバーからの+OKを確認する
	aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_CONNECT_NG",@""),[mAccountItem accountName]];
	[self tlsCheckServerOK:aMsg];
	[self checkKill];
	
	//USERコマンドの発行
	aMsg = [NSString stringWithFormat:@"USER %@\r\n",[mAccountItem userName]];
	[mTlsSocket send:[aMsg cStringUsingEncoding:NSASCIIStringEncoding]];
	[self checkKill];
	
	//サーバーからの+OKを確認する
	aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_USER_NG",@""),[mAccountItem accountName]];
	[self tlsCheckServerOK:aMsg];
	[self checkKill];
	
	//PASSコマンドの発行
	aMsg = [NSString stringWithFormat:@"PASS %@\r\n",[mAccountItem passWord]];
	[mTlsSocket send:[aMsg cStringUsingEncoding:NSASCIIStringEncoding]];
	[self checkKill];
	
	//サーバーからの+OKを確認する
	aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_PASS_NG",@""),[mAccountItem accountName]];
	[self tlsCheckServerOK:aMsg];
	[self checkKill];
	
	if(mRemoveItemArray == nil){ //メール受信の場合
		//STATコマンドの発行
		[mTlsSocket send:"STAT\r\n"];
		[self checkKill];
		
		//STATコマンドの結果を確認する
		if([self tlsCheckSTATresult]){
			//受信しているメールがあるなら、その確認へ
			[self tlsProcMail];
		}	// STATで何もなかったら、そのアカウントの元々あったメールデータを削除する - tls
		else
		{
			NSEnumerator *aItr = [mAppController peepedItemIterator];	
			PeepedItem* aPeepedItem;
			while((aPeepedItem = [aItr nextObject]) != nil)
			{
				if([aPeepedItem accountID] == [mAccountItem accountID])
					[[mAppController peepedItemArray] removeObject:aPeepedItem];
			}
		}

	}else{ //メール削除の場合
		//削除処理へ
		[self tlsProcMail];
	}
	
	//QUITコマンドの発行
	[mTlsSocket send:"QUIT\r\n"];
	
	NS_HANDLER
	[mAppController postStatusRed:[localException reason]]; //例外の理由をステータス表示
	NS_ENDHANDLER
	
	//ソケットオブジェクト,行読み取りオブジェクトを解放する
	[mTlsReadLine release];
	[mTlsSocket release];
	
	[aPool release];
}



//メール収集スレッドのメインループ
- (void)collectMain
{
	NSString *aMsg;
	NSEnumerator *aItr = [mPrefController accountItemIterator];

	//アカウント１つずつ巡回する
	while((mAccountItem = [aItr nextObject]) != nil){
		if(![mAccountItem notUse])
		{
			// ------- for TLS -------
			if ([mAccountItem tls] == YES)
			{
				//NSLog(@"into tls\n");
				[self tlsProcAccount];
			}
			else
				[self procAccount];
		}
		
		if(mUserPause || mErr){
			return;
		}
	}

	//受信したメールの個数をステータス表示する(全体と新規)
	if(mRecvMailCnt == 0){
		aMsg = NSLocalizedString(@"THSTAT_NO_MAIL",@"");
	}else{
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_SOME_MAIL",@""),mRecvMailCnt,mNewMailCnt];
	}
	[mAppController postStatusBlack:aMsg];
}

//現在処理中のアカウントで削除すべきメールがあるかを確認する
//戻り値=YESならある,NOならない
- (BOOL)hasNowAccountMailToRemove
{
	PeepedItem *aItem;
	NSEnumerator *aItr = [mRemoveItemArray objectEnumerator];
	int aAccountID = [mAccountItem accountID];

	while((aItem = [aItr nextObject]) != nil){
		if([aItem accountID] == aAccountID){
			return YES;
		}
	}
	return NO;
}

//メール削除スレッドのメインループ
- (void)removeMain
{
	NSString *aMsg;
	NSEnumerator *aItr = [mPrefController accountItemIterator];

	//アカウント１つずつ巡回する
	while((mAccountItem = [aItr nextObject]) != nil){
		//このアカウントで削除するメールがあるかを確認する
		if([self hasNowAccountMailToRemove]){
			[self procAccount];
		}
		if(mUserPause || mErr){
			return;
		}
	}

	//削除したメールの個数をステータス表示する
	if(mRemoveMailCnt == 0){
		aMsg = NSLocalizedString(@"THSTAT_NO_REMOVE",@"");
	}else{
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"THSTAT_SOME_REMOVE",@""),mRemoveMailCnt];
	}
	[mAppController postStatusBlack:aMsg];
}

//スレッドの本体
- (void)mainThread:(id)iArg
{
	//開始前の準備
	NSAutoreleasePool *aPool = [[NSAutoreleasePool alloc] init];
	[mAppController postChangeThreadStat:YES];
	mRecvMailCnt = mNewMailCnt = mRemoveMailCnt = 0;

	//NSLog(@"WorkerThread.mainThread");

	//処理突入
	if(mRemoveItemArray == nil){ //メール収集の場合
		//NSLog(@"<collectMain start>");
		[self collectMain];
		//NSLog(@"<collectMain end>");
	}else{ //メール削除の場合
		[self removeMain];
	}

	//エラーや中断もしくは新規メール確認状況をメインスレッドに教える
	if(mErr){
		[mAppController postReportErr:YES newMail:NO];
	}else if(mNewMailCnt > 0){
		[mAppController postReportErr:NO newMail:YES];
	}else{
		[mAppController postReportErr:NO newMail:NO];
	}

	//終了時の後始末
	[mRemoveItemArray release];
	[mAppController postChangeThreadStat:NO];
	[aPool release];
}

//例外を放出する
//iMsg=ステータス表示する内容,iErr=YESならエラー発生
- (void)throwException:(NSString *)iMsg error:(BOOL)iErr
{
	if(iErr){
		mErr = YES;
	}
	[[NSException exceptionWithName:@"WorkerThreadException" reason:iMsg userInfo:nil] raise];
}

//エラーであるなら例外を放出する
//iCond=判断式,iMsg=ステータス表示する内容
- (void)ifErr:(BOOL)iCond throwException:(NSString *)iMsg
{
	if(iCond){
		[self throwException:iMsg error:YES];
	}
}



@end

// End Of File































#if 0
//一時保存されている新規メールを取り出す
//戻り値=新規メール,nilならない
- (PeepedItem *)popPeepedItem
{
	PeepedItem *aAns = nil;
	if([mNewPeepArray count] > 0){
		aAns = [[[mNewPeepArray objectAtIndex:0] retain] autorelease];
		[mNewPeepArray removeObjectAtIndex:0];
	}
	return aAns;
}
#endif

//スレッドが走行中ならYES,そうでないならNOを返す
/*- (BOOL)isGoing
{
	return mIsGoing;
}*/


