//
//  STCPCReadLine.m
//  MailPeeper
//
//  Created by Dentom on Mon Sep 09 2002.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import "STCPCReadLine.h"
#import "SimpleTCPClient.h"

@implementation STCPCReadLine

//準備をする(init後にすぐに呼ぶこと)
//iSetup=準備情報
- (void)setupClient:(STCPCReadLineSetup_t *)iSetup
{
	mS = *iSetup;
}

//1行を読み取る
//戻り値.data=読み取ったデータ,戻り値.error=YESならエラー発生
//エラー時にはデータは解放される
//正常時は戻り値.dataにデータオブジェクトが確保されるが、必ず呼び出したほうでreleaseすること(自動解放されない)
- (STCPCReadLine_recv_t)recvLine
{
	STCPCReadLine_recv_t aRes;
	NSMutableData *aData = [[NSMutableData alloc] init];
	BOOL aLoop;

	aRes.data = aData;
	aRes.error = NO;

	for(aLoop = YES; aLoop; ){
		//バッファが読み込まれていないか？
		if(mPopIndex >= mMaxIndex){ //ならば読み取りをする
			NSDate *aTO = [NSDate dateWithTimeIntervalSinceNow:mS.timeOut];
			SimpleTCPClient_send_recv_result aRR;
			do{
				aRR = [mS.client recv:mReadBuff size:STCPCReadLine_BuffSize];
				if(aRR.size < 0){ //エラー発生時
					//EAGAINなら見逃すが違うならエラー扱い
					if(aRR.err != EAGAIN){
						aLoop = NO;
						aRes.error = YES;
					}
				}
				if(aLoop && aRR.size <= 0){ //タイムアウトチェック
					NSDate *aNow = [[NSDate alloc] init];
					if([aNow compare:aTO] == NSOrderedDescending){
						aLoop = NO;
						aRes.error = YES;
					}
					[aNow release];
				}
				if(aLoop && aRR.size <= 0){ //ループする場合は遅延させる
					[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:mS.nextDelay]];
				}
			}while(aLoop && aRR.size <= 0);
			mMaxIndex = aRR.size;
			mPopIndex = 0;
		}else{ //バッファにデータが残っている場合
			char aCh = mReadBuff[mPopIndex++];
			[aData appendBytes:&aCh length:1];
			if(aCh == mS.delim){ //デリミタのチェック
				aLoop = NO;
			}
		}
	}

	//エラー発生時は受信データを解放する
	if(aRes.error){
		[aData release];
		aRes.data = nil;
	}

	return aRes;
}

@end

// End Of File
