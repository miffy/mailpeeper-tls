//
//  AppController.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-10/06.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//
//  Modifired by anne

#import <Cocoa/Cocoa.h>

@class WorkerThread;
@class PrefController;
@class PeepedItem;
@class SimpleSyncFIFO;
@class AccountItem;

@interface AppController : NSObject
{
	//(アウトレット)
	IBOutlet PrefController *mPrefController;	//Prefコントローラー
        IBOutlet NSPanel *mPrefPanel; 				//環境設定パネル
	
	//(アウトレット - メインウィンドウ)
	IBOutlet NSWindow *mMainWin;			//メインウィンドウ
	IBOutlet NSProgressIndicator *mSpin; 	//スピン表示
	IBOutlet NSTextField *mStatus;			//ステータス表示
	IBOutlet NSTableView *mTableView;		//テーブル表示
	IBOutlet NSButton *mGoButton;			//巡回ボタン
	IBOutlet NSButton *mStopButton;			//巡回中止ボタン
	IBOutlet NSButton *mPrefButton;			//環境設定ボタン
	IBOutlet NSButton *mHeaderButton;		//ヘッダ表示ボタン
	IBOutlet NSButton *mDeleteButton;		//削除ボタン
	IBOutlet NSTextField *mSelectStat;		//項目選択数の表示
        //anne
        IBOutlet id sbMenu;

	//(アウトレット以外)
	NSMutableArray *mPeepedItemArray;		//メール受信結果配列 (Pref書類保存対象)
	WorkerThread *mWorkerThread;			//メールチェック専用スレッド
	NSMutableArray *mHeaderWinArray;		//HeaderWinControllerオブジェクト配列
	BOOL mUsingWorkerThread;				//ワーカースレッドを利用中ならYES
	SimpleSyncFIFO *mFIFO;					//ワーカースレッドからの情報受信用
        //anne
        NSStatusItem *sbItem;
        
        
        
}

//(アクションメソッド)
- (IBAction)showHelpMenu:(id)sender;
- (IBAction)showPrefPanel:(id)sender;
- (IBAction)buttonOperation:(id)sender;

//anne
- (IBAction)showMainWindow:(id)sender;
- (void)chooseMailTitle:(id)sender;

//(アクションメソッド以外)
- (void)updateUI;
- (void)updateUIforThread:(BOOL)iBegin;
- (BOOL)usingWorkerThread;
- (void)dispStatusBlack:(NSString *)iMsg;
- (void)dispStatusRed:(NSString *)iMsg;
- (PrefController *)prefController;
- (NSEnumerator *)peepedItemIterator;
- (void)performGoButton;
- (void)reportErr:(BOOL)iErr newMail:(BOOL)iNewMail;
- (void)appendNewMail:(PeepedItem *)iItem pos:(int)iPos;

- (void)postChangeThreadStat:(BOOL)iBegin;
- (void)postStatusBlack:(NSString *)iMessage;
- (void)postStatusRed:(NSString *)iMessage;
- (void)postReportErr:(BOOL)iErr newMail:(BOOL)iNewMail;
- (void)postNewMail:(PeepedItem *)iItem no:(int)iNo;

//anne
- (void)updateAccountMenu;
- (void)accountMenu;
- (NSMutableArray *) mailHeader:(AccountItem *)accountItem;
- (void)addMailTitle;
- (void)deleteMailTitle;
- (void)updateMailTitle;


@end

// End Of File
