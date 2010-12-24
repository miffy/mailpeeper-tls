//
//  PostedEventProc.h
//  MailPeeper
//
//  Created by Dentom on 2002/10/06.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AppController;
@class PeepedItem;

@interface PostedEventProc : NSObject { //ポストされたイベントの共通処理

}
- (void)performAppController:(AppController *)iAppController;
@end

@interface NewMailProc : PostedEventProc { //新規メール到着をメインスレッドに教える用
	PeepedItem *mItem;
	int mNo;
}
- (id)initWithPeepedItem:(PeepedItem *)iItem no:(int)iNo;
- (void)performAppController:(AppController *)iAppController;
@end

@interface ReportErrProc : PostedEventProc { //エラーまたは新規メール確認をメインスレッドに教える用
	BOOL mErr,mNewMail;
}
- (id)initWithErr:(BOOL)iErr newMail:(BOOL)iNewMail;
- (void)performAppController:(AppController *)iAppController;
@end

@interface DispStatusProc : PostedEventProc { //ステータスの表示をメインスレッドに要求する用
	NSString *mMessage;
	BOOL mRed;
}
- (id)initWithMessage:(NSString *)iMessage red:(BOOL)iRed;
- (void)performAppController:(AppController *)iAppController;
@end

@interface ChangeThreadStatus : PostedEventProc { //スレッド開始/終了をメインスレッドに告知する用
	BOOL mBegin;
}
- (id)initWithBegin:(BOOL)iBegin;
- (void)performAppController:(AppController *)iAppController;
@end

// End Of File
