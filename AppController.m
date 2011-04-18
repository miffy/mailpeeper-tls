//
//  AppController.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-11/10.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//
//  Modifired by anne

#import "AppController.h"
#import "Misc.h"
#import "PeepedItem.h"
#import "PrefController.h"
#import "WorkerThread.h"
#import "AccountItem.h"
#import "HeaderWinController.h"
#import "SimpleSyncFIFO.h"
#import "PostedEventProc.h"

//anne
#import "AddressBookController.h"
static int ACCOUNT_MENU = 1001;
static int ACCOUNT_INDEX = 3;


#define	PEEPED_ITEM	@"PEEPED_ITEM_Ver1"	//ログの保存キー
#define TV_AUTOSAVE @"TV_AUTOSAVE_Ver1" //テーブルビューのオートセイブ名

//テーブルビューのidentifier
#define	New_ID		@"NEW"		//新規メール印
#define	Sender_ID	@"SENDER"	//差出人
#define	Subject_ID	@"SUBJECT"	//件名
#define	Date_ID		@"DATE"		//日時
#define	Size_ID		@"SIZE"		//サイズ
#define	Account_ID	@"ACCOUNT"	//アカウント

//操作ボタンのタグ
enum {
	GoButton_TAG = 1,	//巡回ボタン
	StopButton_TAG,		//巡回中止ボタン
	PrefButton_TAG,		//環境設定ボタン
	HeaderButton_TAG,	//ヘッダ表示ボタン
	DeleteButton_TAG,	//削除ボタン
};

@interface AppController(Private)
- (BOOL)canGoing;
- (void)changePeepedItemArrayFlagsSave:(BOOL)iSave clearNewMail:(BOOL)iClearNewMail;
- (void)updateMailLogAfterThreadEnd;
- (NSString *)accountIDtoName:(int)iAccountID;
- (void)dispHeaderWin;
- (void)performDeleteButton;
- (void)timerProc:(NSTimer *)iTimer;
- (void)dispHeaderWinSub:(PeepedItem *)iPeepItem;
@end

@implementation AppController

//初期化メソッド
- (id)init
{
	//NSLog(@"AppController.init");

	if((self = [super init]) != nil){
		//メール受信結果の準備
		mPeepedItemArray = [[NSMutableArray alloc] init];
		//メールチェック専用スレッドの準備
		mWorkerThread = [[WorkerThread alloc] initWithAppController:self];
		//HeaderWinControllerオブジェクト配列の準備
		mHeaderWinArray = [[NSMutableArray alloc] init];
		//ワーカースレッドからの情報受信用FIFOの準備
		mFIFO = [[SimpleSyncFIFO alloc] init];
                
                //anne
                sbItem = [[NSStatusItem alloc] init];
	}
	return self;
}

//ヘルプメニュー
- (IBAction)showHelpMenu:(id)sender
{
	//NSLog(@"AppController.showHelpMenu:%@",sender);
	
	NSString *aHelpHTML = [[NSBundle mainBundle] pathForResource:@"help" ofType:@"html"];
	if(aHelpHTML != nil){
		[[NSWorkspace sharedWorkspace] openFile:aHelpHTML /*withApplication:@"Help Viewer"*/];
	}
}

//受信結果配列へのイテレータを返す
- (NSEnumerator *)peepedItemIterator
{
	return [mPeepedItemArray objectEnumerator];
}

//(メインウィンドウからのデリゲート)
//メインウィンドウがキーウィンドウになった時に呼ばれる
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	//NSLog(@"AppController.windowDidBecomeKey");
	[self updateUI];
}

//(アプリケーションオブジェクトからのデリゲート)
//終了しようとするときに呼ばれる
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	//NSLog(@"<applicationShouldTerminate>");

	//ワーカースレッドが走行中なら終了しない
	if(mUsingWorkerThread){
		NSBeep();
		return NSTerminateCancel;
	}

	//受信ログを保存する
	[Misc writeDataPref:mPeepedItemArray key:PEEPED_ITEM];

	return NSTerminateNow;
}

//(メインウィンドウからのデリゲート)
//閉じようとするときに呼ばれる
/*anne
- (BOOL)windowShouldClose:(id)sender
{
	//NSLog(@"<windowShouldClose>");

	//ワーカースレッドが走行中なら閉じない
	if(mUsingWorkerThread){
		NSBeep();
		return NO;
	}

	return YES;
}
*/


//メニューの更新で呼ばれる
- (BOOL)validateMenuItem:(NSMenuItem *)iMenuItem
{
	SEL aMenuSel = [iMenuItem action];
	//NSLog(@"AppController.validateMenuItem:%@",iMenuItem);

	//メニューの表示調整
	if(aMenuSel == @selector(showPrefPanel:)){ //環境設定メニュー
		return !mUsingWorkerThread;
	}else if(aMenuSel == @selector(buttonOperation:)){ //操作ボタンにあるのと同じメニュー
		switch([iMenuItem tag]){
		case GoButton_TAG: //巡回
			return [self canGoing];

		case StopButton_TAG: //巡回中止
			return mUsingWorkerThread;

		case HeaderButton_TAG: //ヘッダ表示
			return ([mTableView selectedRow] >= 0) && !mUsingWorkerThread;

		case DeleteButton_TAG: //削除
			return ([mTableView selectedRow] >= 0) && [self canGoing];

		}
	}else if(aMenuSel == @selector(showHelpMenu:)){ //ヘルプメニュー
		return YES;
        
        //anne
	}else if(aMenuSel == @selector(showMainWindow:)){
                return YES;
        }else if(aMenuSel == @selector(chooseMailTitle:)){
                return YES;
        }

	return NO;
}

//UIの更新が要求された
- (void)updateUI
{
	BOOL aCanGoing = [self canGoing];
	BOOL aTVselected = ([mTableView selectedRow] >= 0);

	//巡回ボタンの調整
	[mGoButton setEnabled:aCanGoing];

	//巡回中止ボタンの調整
	[mStopButton setEnabled:mUsingWorkerThread];

	//環境設定ボタンの調整
	[mPrefButton setEnabled:!mUsingWorkerThread];

	//ヘッダ表示ボタンの調整
	[mHeaderButton setEnabled:(aTVselected && !mUsingWorkerThread)];
	
	//削除ボタンの調整
	[mDeleteButton setEnabled:(aTVselected && aCanGoing)];
}

//updateUIと同じだがワーカースレッドの起動/停止時に発生する大きな変化も対応する
//iBegin=YESならワーカースレッド起動、NOならワーカースレッドの停止
- (void)updateUIforThread:(BOOL)iBegin
{
	mUsingWorkerThread = iBegin;

	[self updateUI];

	if(iBegin){
		//スレッド起動時
		[mSpin startAnimation:self]; //スピン表示開始
		[mPrefPanel orderOut:self];  //環境設定パネルを隠す
            }else{
		//スレッド終了時
		[self updateMailLogAfterThreadEnd]; //メール表示の更新
		[mSpin stopAnimation:self]; //スピン表示停止
	}
}

//ワーカースレッド利用中ならYES,さもなくばNOを返す
- (BOOL)usingWorkerThread
{
	return mUsingWorkerThread;
}

//Prefコントローラーを返す
- (PrefController *)prefController
{
	return mPrefController;
}

//(テーブルビューからのデリゲート)
//選択状況が変化したときに呼ばれる
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int aSelectedRows; //選択項目数
	NSString *aMsg;

	//選択項目数を表示する
	aSelectedRows = [mTableView numberOfSelectedRows];
	if(aSelectedRows == 0){
		aMsg = @"";
	}else{
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"SEL_TV_ITEMS",@""),aSelectedRows];
	}
	[mSelectStat setStringValue:aMsg];

	//UIの更新
	[self updateUI];
}

//(テーブルビューからのデリゲート)
//テーブルビューの行数を教える
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [mPeepedItemArray count];
}

//(テーブルビューからのデリゲート)
//テーブルビューの表示内容を教える
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	NSString *aID = [tableColumn identifier];
	PeepedItem *aItem = [mPeepedItemArray objectAtIndex:row];

	if([aID isEqualToString:New_ID]){ //新規メール印
		return [aItem newMailMark];
	}else if([aID isEqualToString:Sender_ID]){ //差出人
		return [aItem from];
	}else if([aID isEqualToString:Subject_ID]){ //件名
		return [aItem subject];
	}else if([aID isEqualToString:Date_ID]){ //日時
		return [aItem date];
	}else if([aID isEqualToString:Size_ID]){ //サイズ
		return [NSString stringWithFormat:@"%d",[aItem mailSize]];
	}else if([aID isEqualToString:Account_ID]){ //アカウント
		return [self accountIDtoName:[aItem accountID]];
	}

	//(ここに来ることはないはず)
	return @"(error)";
}

//nibファイルから実体化された後、呼び出される
- (void)awakeFromNib
{
	id aObj;

	//スピン表示は停止中なら隠す
	[mSpin setDisplayedWhenStopped:NO];
	//ステータス表示は「待機中」に
	[self dispStatusBlack:NSLocalizedString(@"NOW_WAITING",@"")];
	//項目選択数の表示をクリア
	[mSelectStat setStringValue:@""];

	//テーブルビューのオートセーブ
	[mTableView setAutosaveName:TV_AUTOSAVE];
	[mTableView setAutosaveTableColumns:YES];

	//受信ログを復元する
	aObj = [Misc readDataPrefKey:PEEPED_ITEM];
	if(aObj != nil){
		[mPeepedItemArray autorelease];
		mPeepedItemArray = [aObj retain];
	}

	//ワーカースレッドからの情報受信用タイマーの発生
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerProc:) userInfo:nil repeats:YES];
}

//ステータス表示をする(dispStatusBlackは黒,dispStatusRedは赤表示)
//iMsg=表示したいメッセージ
- (void)dispStatusBlack:(NSString *)iMsg
{
	[mStatus setTextColor:[NSColor blackColor]];
	[mStatus setStringValue:iMsg];
}

- (void)dispStatusRed:(NSString *)iMsg
{
	[mStatus setTextColor:[NSColor redColor]];
	[mStatus setStringValue:iMsg];
}

//(アプリケーションオブジェクトからのデリゲート)
//アプリケーション起動時に呼び出される
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	//10.2以前のヴァージョンなら終了する
	if(![Misc is_10_2_or_later_version]){
		NSBeep();
		NSRunCriticalAlertPanel(nil,NSLocalizedString(@"VERSION_WARNING",@""),nil,nil,nil);
		[NSApp terminate:self];
		return;
	}
}

//(アプリケーションオブジェクトからのデリゲート)
//最後のウィンドウが閉じたらアプリケーションを終了させるかの判断
/*anne
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES; //終了させる
}
*/

//環境設定パネルを要求されたときに呼ばれる
- (IBAction)showPrefPanel:(id)sender
{
	//NSLog(@"AppController.showPrefPanel");

	//すでにワーカースレッドが走行中なら戻る
	if(mUsingWorkerThread){
		return;
	}
        
        //anne
        [NSApp activateIgnoringOtherApps: YES];
        
	//環境設定パネルを表示する
	[mPrefPanel makeKeyAndOrderFront:self];
	//環境設定パネルの中身の表示を調整する
	[mPrefController updateUI];
}

//操作ボタンが押されたときに呼ばれる
- (IBAction)buttonOperation:(id)sender
{
	switch([sender tag]){
	case GoButton_TAG: //巡回ボタン
		[self performGoButton];
		break;

	case StopButton_TAG: //巡回中止ボタン
		[mWorkerThread userAbort];
		break;

	case PrefButton_TAG: //環境設定ボタン
		[self showPrefPanel:sender];
		break;

	case HeaderButton_TAG: //ヘッダ表示ボタン
		if(!mUsingWorkerThread){
			[self dispHeaderWin];
		}
		break;

	case DeleteButton_TAG: //削除ボタン
		[self performDeleteButton];
		break;
	}
}

//巡回ボタンを押したときの振る舞い
- (void)performGoButton
{
	//NSLog(@"performGoButton-entry");

	if([self canGoing]){ //ワーカースレッドが走行可能なら
		//ワーカースレッドの利用開始
		mUsingWorkerThread = YES;

		//NSLog(@"performGoButton-canGoing");

		//進行中のDockアイコンに変更する
		//[NSApp setApplicationIconImage:[NSImage imageNamed:@"appl-walking"]];
                
                //anne
                //アイコンをかえる
                [sbItem setImage: [NSImage imageNamed: @"mail-r"]];

		//保存フラグ,新規メール印をオールクリアする
		[self changePeepedItemArrayFlagsSave:NO clearNewMail:YES];

		//スレッドを走らせる
		[mWorkerThread run:nil];
	}

	//NSLog(@"performGoButton-exit");
}

//ワーカースレッドのエラー、新規メール発生状況をメインスレッドに教える
//音声で知らせる(設定次第)、ドックのアイコンをバウンスさせる
//iErr=エラーありならYES,iNewMail=新規メールありならYES
- (void)reportErr:(BOOL)iErr newMail:(BOOL)iNewMail
{
	if(iErr){
		//[NSApp setApplicationIconImage:[NSImage imageNamed:@"appl-error"]];
		[NSApp requestUserAttention:NSCriticalRequest];
		[mPrefController speakError];
                //anne
                //エラーアイコンに
                [sbItem setImage: [NSImage imageNamed: @"mail-error"]];
                
	}else if(iNewMail){
		//[NSApp setApplicationIconImage:[NSImage imageNamed:@"appl-newmail"]];
                //anne-新規メール受信時にドックアイコンがはねないように以下をコメントアウト
		//[NSApp requestUserAttention:NSCriticalRequest];
                
                //anneNewアイコンに
                [sbItem setImage: [NSImage imageNamed: @"mail-new"]];
                
                
		[mPrefController speakNewMail];
	}else{
		//[NSApp setApplicationIconImage:[NSImage imageNamed:@"NSApplicationIcon"]];
                
                //anne-アイコンを元に戻す
                [sbItem setImage: [NSImage imageNamed: @"mail"]];
                
	}
}

//ワーカースレッドの取得した新規メール情報を処理する
//iItem=新規メール情報、iPos=取得した順番(1〜)
- (void)appendNewMail:(PeepedItem *)iItem pos:(int)iPos
{
	[mPeepedItemArray insertObject:iItem atIndex:iPos - 1];

	//テーブルビュー表示更新
	[mTableView reloadData];
}

//ワーカースレッドがスレッド開始/終了をメインスレッドに告知する
//iBegin=YESならワーカースレッド開始,NOならワーカースレッド終了
- (void)postChangeThreadStat:(BOOL)iBegin
{
	ChangeThreadStatus *aEvt = [[ChangeThreadStatus alloc] initWithBegin:iBegin];
	[mFIFO push:aEvt];
	[aEvt release];
}

//ワーカースレッドがステータスの表示をメインスレッドに要求する
//iMessage=表示メッセージ
- (void)postStatusBlack:(NSString *)iMessage
{
	DispStatusProc *aEvt = [[DispStatusProc alloc] initWithMessage:iMessage red:NO];
	[mFIFO push:aEvt];
	[aEvt release];
}

- (void)postStatusRed:(NSString *)iMessage
{
	DispStatusProc *aEvt = [[DispStatusProc alloc] initWithMessage:iMessage red:YES];
	[mFIFO push:aEvt];
	[aEvt release];
}

//ワーカースレッドがエラーまたは新規メール確認をメインスレッドに教える
//iErr=YESならエラー発生,iNewMail=YESなら新規メールあり
- (void)postReportErr:(BOOL)iErr newMail:(BOOL)iNewMail
{
	ReportErrProc *aEvt = [[ReportErrProc alloc] initWithErr:iErr newMail:iNewMail];
	[mFIFO push:aEvt];
	[aEvt release];
}

//ワーカースレッドが新規メール到着をメインスレッドに教える
//iItem=メールの内容,iNo=確認した順番(1〜)
- (void)postNewMail:(PeepedItem *)iItem no:(int)iNo
{
	NewMailProc *aEvt = [[NewMailProc alloc] initWithPeepedItem:iItem no:iNo];
	[mFIFO push:aEvt];
	[aEvt release];
}



//anne-ステータスバーを作成する
- (void) applicationDidFinishLaunching : (NSNotification *) aNote 
{
    // ステータスバー作成
    NSStatusBar *bar = [ NSStatusBar systemStatusBar ];
    
   // appsStatusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: 27.0];

    { // ステータスアイテム作成
        //NSStatusItem *sbItem = [ bar statusItemWithLength : NSVariableStatusItemLength ];
        sbItem = [ bar statusItemWithLength : NSVariableStatusItemLength ];
                
        [ sbItem retain ];
        
        //[ sbItem setTitle : @"Mail" ]; // タイトルをセット
        [ sbItem setImage: [NSImage imageNamed: @"mail"]];
        //anne
        //未受信のメール数を表示
        NSMutableAttributedString *attStr = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d",[mPeepedItemArray count]]] autorelease];
        [attStr addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0,[attStr length])]; 
        [sbItem setAttributedTitle:attStr];

        [ sbItem setToolTip : @"MailPeeper_Menu" ]; // ツールチップをセット
        [ sbItem setHighlightMode : YES ]; // クリック時にハイライト表示
        [ sbItem setMenu : sbMenu ]; // メニューをセット
    }
    
    [self accountMenu];
    [self updateMailTitle];
    
}


//anne-メインウィンドウを要求されたときに呼ばれる
- (IBAction)showMainWindow:(id)sender
{
        
        [NSApp activateIgnoringOtherApps: YES];
	//MainWindowを表示する
	[mMainWin makeKeyAndOrderFront:self];
}

//anne
//account Menuを更新する時に呼ぶ
- (void)updateAccountMenu
{
    //account Menuを取り除く
    id item;
    int deleteIndex = 0;
    NSEnumerator *enumerator = [[sbMenu itemArray] objectEnumerator];
    while (item = [enumerator nextObject]) {
        if ([item tag] == ACCOUNT_MENU) {
            deleteIndex = [sbMenu indexOfItem:item];
            [sbMenu removeItemAtIndex:deleteIndex];
        }
    }
    
    //account Menuを再構成する
    [self accountMenu];
    [self updateMailTitle];
}




//anne
- (void) accountMenu
{
    NSEnumerator *aItr = [mPrefController accountItemIterator];
    AccountItem *aItem;
    
    while((aItem = [aItr nextObject]) != nil){
        
        NSMenuItem *newItem;
        NSMenu *mailHeaderMenu = [[NSMenu alloc] initWithTitle:[aItem accountName]];
        newItem = [[NSMenuItem alloc] init];
        [newItem setTitle:[aItem accountName]];
        //account menuを追加
        [sbMenu insertItem:newItem atIndex:ACCOUNT_INDEX];
        //menuを消去する時のためにtagを1001にしておく
        [newItem setTag:ACCOUNT_MENU];
        //subMenu化
        [newItem setSubmenu:mailHeaderMenu];
        [newItem release];
		[mailHeaderMenu release];
    }//while

}

//anne
//mailTitleを更新する時に呼ぶ。
-(void)updateMailTitle
{
    [self deleteMailTitle];
    [self addMailTitle];
    
}

//anne
//updateMailTitleを使う
-(void)addMailTitle
{
    id item;
    NSEnumerator *enumerator = [[sbMenu itemArray] objectEnumerator];
    //account menuを探す
    while (item = [enumerator nextObject]) {
        if ([item tag] == ACCOUNT_MENU) {
            NSEnumerator *aItr = [mPrefController accountItemIterator];
            AccountItem *aItem;
            while((aItem = [aItr nextObject]) != nil){
                if ([[aItem accountName] isEqualToString:[[item submenu] title]]){
    
                    NSEnumerator *enume = [[self mailHeader:aItem] objectEnumerator];
                    NSString *mailTitle;

                    while (mailTitle = [enume nextObject]) {
                        NSMenuItem *aMenuItem =[[NSMenuItem alloc] init];
                        [aMenuItem setTitle:mailTitle];
                        [aMenuItem setTarget:self];
                        [aMenuItem setAction:@selector(chooseMailTitle:)];
                        [[item submenu] addItem:aMenuItem];
                        [aMenuItem release];
                    }//while
                }//if
            }//while
        }//if
    }//while
}//addMailTitle

//anne
- (void)chooseMailTitle:(id)sender
{
    //NSLog(@"%d",[[sender menu] indexOfItem:sender]);
    NSMutableArray *mail = [NSMutableArray arrayWithCapacity:256];
    NSEnumerator *enumerator = [mPeepedItemArray objectEnumerator];
    PeepedItem *aItem;
    while (aItem = [enumerator nextObject]) {
        if([[self accountIDtoName:[aItem accountID]] isEqualToString:[[sender menu] title]]){
            [mail addObject:aItem];
        }
    }
    
    PeepedItem *mailItem = [mail objectAtIndex:[[sender menu] indexOfItem:sender]];
    [self dispHeaderWinSub:mailItem];
}



//anne
//updateMailTitleを使う
-(void)deleteMailTitle
{
    id item;
    NSEnumerator *enumerator = [[sbMenu itemArray] objectEnumerator];
    while (item = [enumerator nextObject]) {
        if ([item tag] == ACCOUNT_MENU) {
            NSEnumerator *enume = [[[item submenu] itemArray] objectEnumerator];
            id aItem;
            while (aItem = [enume nextObject]) {
                [[item submenu] removeItem:aItem];
            }
        }
    }
}


//anne
//与えられたaccountItemのメールタイトルを配列で返す
- (NSMutableArray *) mailHeader:(AccountItem *)accountItem
{
    NSMutableArray *mailData = [NSMutableArray arrayWithCapacity:256];
    
    NSEnumerator *enumerator = [mPeepedItemArray objectEnumerator];
    PeepedItem *aItem;

    while (aItem = [enumerator nextObject]) {
    	if ([[self accountIDtoName:[aItem accountID]] isEqualToString:[accountItem accountName]]){
            NSMutableString *mailTitle = [NSMutableString stringWithCapacity:256];
            [mailTitle appendString:[aItem subject]];
            [mailTitle appendString:@":"];
            [mailTitle appendString:[aItem from]];
            
            [mailData addObject:mailTitle];
        }
    }
    return mailData;
}


@end

@implementation AppController(Private)

//メールチェックスレッドが走行可能かを調べる
//戻り値=YESなら可能,NOなら不可能

- (BOOL)canGoing
{
        //すでにワーカースレッドを利用中ならNO
	if(mUsingWorkerThread){
		return NO;
	}

	//巡回できるアカウントがないならNO
	if(![mPrefController hasWalkableAccount]){
		return NO;
	}
	
	//環境設定パネルがシートを開いているならNO
	if([mPrefController isDispSheet]){
		return NO;
	}

	return YES;
}



//メール受信結果配列の保存フラグをオールクリアまたはオールセットする
//同時に新規メール印をオールクリアするか、しない
//iSave=YESなら保存フラグをオールセット,NOならオールクリア
//iClearNewMail=YESなら新規メール印をオールクリア,NOなら新規メール印を変更しない
- (void)changePeepedItemArrayFlagsSave:(BOOL)iSave clearNewMail:(BOOL)iClearNewMail
{
	PeepedItem *aItem;
	NSEnumerator *aItr = [self peepedItemIterator];

	while((aItem = [aItr nextObject]) != nil){
		[aItem setSaveFlag:iSave];
		if(iClearNewMail){
			[aItem setNewMailFlag:NO];
		}
	}
}

//スレッド終了後のメール表示の更新
- (void)updateMailLogAfterThreadEnd
{
	PeepedItem *aItem;
	int aIndex;

	//テーブルビューの選択を解除する
	[mTableView deselectAll:self];

	//メール受信結果配列の保存フラグの立っていない記録を削除する
	for(aIndex = [mPeepedItemArray count] - 1; aIndex >= 0; aIndex--){
		aItem = [mPeepedItemArray objectAtIndex:aIndex];
		if(![aItem saveFlag]){
			[mPeepedItemArray removeObjectAtIndex:aIndex];
		}
	}

	//テーブルビュー表示更新
	[mTableView reloadData];
        
        //anne
        //未受信のメール数を表示
        NSMutableAttributedString *attStr = [[[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d",[mPeepedItemArray count]]] autorelease];
        [attStr addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0,[attStr length])]; 
        [sbItem setAttributedTitle:attStr];
        
        //[sbItem setTitle:[NSString stringWithFormat:@"%d",[mPeepedItemArray count]]];
        [self updateMailTitle];
        //NSNumber *number;
        //number = [NSNumber numberWithUnsignedInt:[mPeepedItemArray count]];
        //[sbItem setTitle:[number stringValue]];
}

//アカウントIDからアカウント名をえる
- (NSString *)accountIDtoName:(int)iAccountID
{
	NSEnumerator *aItr = [mPrefController accountItemIterator];
	AccountItem *aItem;
	
	while((aItem = [aItr nextObject]) != nil){
		if([aItem accountID] == iAccountID){
			return [aItem accountName];
		}
	}
	
	//(ここに来ることはないが念のため)
	return @"(error)";
}

//dispHeaderWinの下請け
- (void)dispHeaderWinSub:(PeepedItem *)iPeepItem
{
	HeaderWinController *aHWC;
	int aIndex;
	BOOL aNotOpened = YES;

	//配列を巡回する
	for(aIndex = [mHeaderWinArray count] - 1; aIndex >= 0; aIndex--){
		aHWC = [mHeaderWinArray objectAtIndex:aIndex];
		if([aHWC deleted]){
			//削除フラグが立っているなら削除する
			[mHeaderWinArray removeObjectAtIndex:aIndex];
		}else if([aHWC isEqualToPeepedItem:iPeepItem]){
			//すでに開いているなら、そのウィンドウを前に出す
                        
                        //anne
                        [NSApp activateIgnoringOtherApps: YES];
			
                        [aHWC showFront];
			aNotOpened = NO;
		}
	}

	//まだ開いていないなら新規作成
	if(aNotOpened){
		aHWC = [[[HeaderWinController alloc] initWithAppController:self peepedItem:iPeepItem] autorelease];
		[mHeaderWinArray addObject:aHWC];
	}
}

//ヘッダー表示ウィンドウを表示する
- (void)dispHeaderWin
{
	NSEnumerator *aItr = [mTableView selectedRowEnumerator];	//TODO: selectedRowIndexesで置換すべき
//	NSEnumerator *aItr = [mTableView selectedRowIndexes];
	NSNumber *aNum;

	//選択しているテーブルビューを元に処理
	while((aNum = [aItr nextObject]) != nil){
		PeepedItem *aPeepItem = [mPeepedItemArray objectAtIndex:[aNum intValue]];
		[self dispHeaderWinSub:aPeepItem];
	}
}

//削除ボタンが押されたときの処理
- (void)performDeleteButton
{
	int aRes;
	NSEnumerator *aItr;
	NSNumber *aNum;
	NSMutableArray *aRemoveItemArray; //削除すべきメール情報

	//テーブルビューで選択されている項目がないなら戻る
	//メールチェックスレッドが走行可能な状況でないなら戻る
	if(([mTableView selectedRow] < 0) || ![self canGoing]){
		return;
	}

	//ワーカースレッドの利用開始
	mUsingWorkerThread = YES;

	//削除すべきメール情報を配列にためこむ
	aRemoveItemArray = [NSMutableArray array];
	aItr = [mTableView selectedRowEnumerator];	//TODO: selectedRowIndexesで置換すべき
//	aItr = [mTableView selectedRowIndexes];
	while((aNum = [aItr nextObject]) != nil){
		PeepedItem *aPeepItem = [mPeepedItemArray objectAtIndex:[aNum intValue]];
		[aRemoveItemArray addObject:aPeepItem];
	}

	//削除していいかをユーザーに確認する
	aRes = NSRunAlertPanel(NSLocalizedString(@"DEL_MAIL_TITLE",@"タイトル"),
						   [NSString stringWithFormat:NSLocalizedString(@"DEL_MAIL_QUESTION",@""),
													  [aRemoveItemArray count]],
						   NSLocalizedString(@"DEL_MAIL_NO",@"中止します(default)"),
						   NSLocalizedString(@"DEL_MAIL_YES",@"削除します(alt.)"),
						   nil);
	if(aRes != NSAlertAlternateReturn){
		mUsingWorkerThread = NO;
		return;
	}

	//メール受信結果配列の保存フラグをオールセットする
	[self changePeepedItemArrayFlagsSave:YES clearNewMail:NO];

	//スレッドを走らせる
	[mWorkerThread run:aRemoveItemArray];
}

//ワーカースレッドからの情報受信用タイマー
- (void)timerProc:(NSTimer *)iTimer
{
	PostedEventProc *aEvt;
	
	while((aEvt = [mFIFO popEasy]) != nil){
		[aEvt performAppController:self];
	}
}



@end

// End Of File
