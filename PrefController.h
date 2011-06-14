//
//  PrefController.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-10/04.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

@class GeneralItem;
@class AccountItem;
@class AppController;

@interface PrefController : NSObject<GrowlApplicationBridgeDelegate>
{
	//(アウトレット)
	IBOutlet NSWindow *mGeneralSheet;		//巡回の設定シート
	IBOutlet NSWindow *mAccountSheet;		//アカウント編集シート
	IBOutlet AppController *mAppController;	//アプリケーションコントローラー
	
	//(アウトレット - 巡回の設定シート)
	IBOutlet NSButton *mGoAtStart_CB;		//「プログラム起動時に巡回開始」チェックボックス
	IBOutlet NSButton *mRepeat_CB;			//「定期的に巡回する」チェックボックス
	IBOutlet NSTextField *mRepeat_TF;		//「分ごとに巡回する」テキストフィールド
	IBOutlet NSButton *mNewMailVoice_CB;	//「新規メールで音声」チェックボックス
	IBOutlet NSTextView *mNewMailVoice_TV;	//「新規メールの音声」テキストビュー
	IBOutlet NSButton *mErrorVoice_CB;		//「エラーで音声」チェックボックス
	IBOutlet NSTextView *mErrorVoice_TV;	//「エラーで音声」テキストビュー
	
	IBOutlet NSButton *mGoAtResume_CB;		//「スリープ復帰時に巡回開始」チェックボックス
	IBOutlet NSButton *mNewMailSound_CB;	//「着信音」チェックボックス
//	IBOutlet NSButton *mNewMailSound_Button;//「着信音」ファイル選択ダイアログ立ち上げボタン
	IBOutlet NSTextField *mNewMailSound_TF;	//「着信音」テキストフィールド
	IBOutlet NSButton *mErrorSound_CB;		//「エラー音」チェックボックス
//	IBOutlet NSButton *mErrorSound_Button;	//「エラー音」ファイル選択ダイアログ立ち上げボタン
	IBOutlet NSTextField *mErrorSound_TF;	//「エラー音」テキストフィールド
	IBOutlet NSButton *mNewMailGrowl_CB;	//「Growlで通知」チェックボックス
	
	//(アウトレット - アカウント編集シート)
	IBOutlet NSForm *mAccountForm;				//「アカウント名」〜「ユーザー名」
	IBOutlet NSSecureTextField *mPassword_TF;	//「パスワード」テキストフィールド
	IBOutlet NSButton *mTls_CB;					// TLS対応
	
	//(アウトレット - 環境設定パネル)
    IBOutlet NSPanel *mPrefPanel; 			//環境設定パネル
	IBOutlet NSTableView *mTableView;		//テーブル表示
	IBOutlet NSButton *mEditButton;			//「編集...」ボタン
	IBOutlet NSButton *mDeleteButton;		//「削除...」ボタン
	IBOutlet NSButton *mToTopButton;		//「このアカウントを先頭にする」ボタン
	IBOutlet NSButton *mStopWalkButton;		//「一時的な巡回中止」ボタン
	IBOutlet NSButton *mReWalkButton;		//「巡回を再開」ボタン
	
	//(ここからはアウトレット以外)
	GeneralItem *mGeneralItem;				//巡回設定情報 (Pref書類保存対象)
	NSMutableArray *mAccountItemArray;		//アカウント設定情報 (Pref書類保存対象) (AccountItemの配列)
	BOOL mDispSheet;						//シート表示中かフラグ
	BOOL mAppendAcc;						//YESなら「新規アカウントを追加」,NOなら「編集...」
	AccountItem *mEditAccount;				//編集対象のアカウント
	int mRepeatTimer;						//定期巡回のために1分ごと増加する
}

//(アクション)
- (IBAction)buttonOperation:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)chooseFile:(id)sender;

//(ここからはアクション以外)
- (void)updateUI;
- (BOOL)isDispSheet;
- (BOOL)hasWalkableAccount;
- (NSEnumerator *)accountItemIterator;
- (void)speakNewMail;
- (void)speakError;
- (void)notifyNewMailBySound;
- (void)notifyErrorBySound;
- (void)notifyNewMailByGrowl:(NSMutableArray *)mPeepedItemArray;
- (void)growlNotificationWasClicked:(id)clickContext;
@end

// End Of File
