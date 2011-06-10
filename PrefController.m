//
//  PrefController.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-10/04.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//
//  Modifired by anne, miff(modifiedじゃない？)

#import "PrefController.h"
#import "AccountItem.h"
#import "AppController.h"
#import "GeneralItem.h"
#import "Misc.h"
#import "PeepedItem.h"
#include <unistd.h>

#define GENERAL_DICT	@"GENERAL_DICT"			//巡回の設定の保存キー
#define	ACCOUNT_ITEM	@"ACCOUNT_ITEM_Ver1"	//アカウント設定の保存キー

//操作ボタンのタグ
enum {
	GeneralButton_TAG = 1,	//巡回の設定...
	EditButton_TAG,			//編集...
	DeleteButton_TAG,		//削除...
	ToTopButton_TAG,		//このアカウントを先頭にする
	StopWalkButton_TAG,		//一時的な巡回中止
	ReWalkButton_TAG,		//巡回を再開
	AppendAccButton_TAG		//新規アカウントを追加...
};

//シート上のボタンのタグ
enum {
	General_OK_TAG = 1,		//巡回の設定 - 決定
	General_CAN_TAG,		// "       - キャンセル
	Account_OK_TAG,			//アカウント - 決定
	Account_CAN_TAG			// "       - キャンセル
};

enum {
	NewMailSound_TAG = 1,	//メールが来たときの音ファイルの設定
	ErrorSound_TAG			//エラーが起こった時の音ファイルの設定	
};

//アカウントシートのフォームのインデックス値
enum {
	AccountName_Index,		//アカウント名
	PopName_Index,			//POPサーバー名
	PortNo_Index,			//ポート番号
	UserName_Index,			//ユーザー名
};

@interface PrefController(Private)
- (void)sheetOperation:(NSWindow *)iSheet;
- (BOOL)pressedGeneralOK;
- (BOOL)pressedAccountOK;
- (void)setupGeneralSheet;
- (void)setupAccountSheet;
- (NSFormCell *)accountFormCell:(int)iIndex;
- (BOOL)checkAccountNameRegist:(NSString *)iName except:(AccountItem *)iExcept;
- (AccountItem *)accountItem:(int)iIndex;
- (void)deleteAccountProc;
- (void)toTopAccountProc;
- (void)walkAccountProc:(BOOL)iStop;
- (void)timerProc:(NSTimer *)iTimer;
- (void)receiveWakeNotification:(NSNotification *)notification;
@end

@implementation PrefController	

//初期化メソッド
- (id)init
{
	//NSLog(@"PrefController.init");

	if((self = [super init]) != nil){
		//巡回設定情報の準備
		mGeneralItem = [[GeneralItem alloc] init];
		//アカウント設定情報の準備
		mAccountItemArray = [[NSMutableArray alloc] init];
	}
	return self;
}

//(環境設定パネルからのデリゲート)
//シート表示開始時に呼ばれる
- (void)windowWillBeginSheet:(NSNotification *)aNotification
{
	mDispSheet = YES;
	[mAppController updateUI];	//メインウィンドウの表示変更を要請する
}

//(環境設定パネルからのデリゲート)
//シート表示終了時に呼ばれる
- (void)windowDidEndSheet:(NSNotification *)aNotification
{
	mDispSheet = NO;
	[mAppController updateUI];	//メインウィンドウの表示変更を要請する
}

//(環境設定パネルからのデリゲート)
//環境設定パネルがキーウィンドウになった時に呼ばれる
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
	[self updateUI];
}

//UIの更新が要求された
- (void)updateUI
{
	BOOL aBool;
	int aSelectedRow = [mTableView selectedRow]; //テーブルビューの選択されている行
	AccountItem *aItem = [self accountItem:aSelectedRow]; //選択されているアカウント情報

	//NSLog(@"PrefController.updateUI");

	//「編集...」ボタン,「削除...」ボタン
	aBool = (aSelectedRow >= 0);
	[mEditButton setEnabled:aBool];
	[mDeleteButton setEnabled:aBool];

	//「このアカウントを先頭にする」ボタン
	[mToTopButton setEnabled:(aSelectedRow > 0)];

	//「一時的な巡回中止」ボタン
	aBool = (aItem == nil) ? NO: ![aItem notUse];
	[mStopWalkButton setEnabled:aBool];

	//「巡回を再開」ボタン
	aBool = (aItem == nil) ? NO: [aItem notUse];
	[mReWalkButton setEnabled:aBool];
}

//シート表示中ならYES,さもなくばNOを返す
- (BOOL)isDispSheet
{
	return mDispSheet;
}

//シート上のボタンが押されたときに呼び出される
- (IBAction)closeSheet:(id)sender
{
	NSWindow *aCloseSheet = nil;	//閉じるべきシートの指定
	BOOL aAccountProcEnd = NO;		//YESならアカウント編集のシートだった

	switch([sender tag]){
	case General_OK_TAG: //巡回の設定 - 決定
		if([self pressedGeneralOK]){
			aCloseSheet = mGeneralSheet;
		}
		break;

	case General_CAN_TAG: //巡回の設定 - キャンセル
		aCloseSheet = mGeneralSheet;
		break;

	case Account_OK_TAG: //アカウント - 決定
		if([self pressedAccountOK]){
			aAccountProcEnd = YES;
			aCloseSheet = mAccountSheet;
                        //anne
                        [mAppController updateAccountMenu];
		}
		break;

	case Account_CAN_TAG: //アカウント - キャンセル
		aAccountProcEnd = YES;
		aCloseSheet = mAccountSheet;
		break;
	
	}

	//アカウント追加時にはmEditAccountをreleaseする必要がある
	if(aAccountProcEnd){
		if(mAppendAcc){
			[mEditAccount release];
		}
		mEditAccount = nil;
	}

	//シートを隠す処理
	if(aCloseSheet != nil){
		//シートを隠す
		[aCloseSheet orderOut:sender];
		//通常のイベントハンドリングに戻す
		[NSApp endSheet:aCloseSheet returnCode:0];
		[mPrefPanel makeKeyAndOrderFront:self];
	}
}

//シート上のボタンが押されたときに呼び出される
- (IBAction)chooseFile:(id)sender
{
	NSString *path = NULL;					//音のファイルパス
	int result;
	NSArray *filesToOpen;
	NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	NSArray *fileTypes = [NSSound soundUnfilteredTypes];
	// All file types NSSound understands
	[oPanel setAllowsMultipleSelection:NO];
	result = [oPanel runModalForDirectory:@"/System/Library/Sounds/" file:nil types:fileTypes];
	if (result == NSOKButton)
	{
        filesToOpen = [oPanel filenames];
        path = [filesToOpen objectAtIndex:0];		
    }else {
		return;
	}
	
	switch([sender tag]){
	case NewMailSound_TAG:	//メールが来たときの音ファイルの設定
		if(path != NULL){
			[mNewMailSound_TF setStringValue:path];			
		}
		break;
	
	case ErrorSound_TAG:	//エラーが起こった時の音ファイルの設定
		if(path != NULL){
			[mErrorSound_TF setStringValue:path];
		}
		break;
	}
}	


//(テーブルビューからのデリゲート)
//テーブルビューの行数を教える
- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [mAccountItemArray count];
}

//(テーブルビューからのデリゲート)
//テーブルビューの表示内容を教える
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	AccountItem *aItem = [mAccountItemArray objectAtIndex:row];

	if([aItem notUse]){
		//巡回中止中の場合
		return [NSString stringWithFormat:NSLocalizedString(@"STOP_WALKING",@""),[aItem accountName]];
	}else{
		//巡回中の場合
		return [aItem accountName];
	}
}

//(テーブルビューからのデリゲート)
//テーブルビューの選択状況が変化したら呼ばれる
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self updateUI];
}

//nibファイルから実体化された後、呼び出される
- (void)awakeFromNib
{
	id aObj;

	//巡回設定情報を復元する
	aObj = [Misc readDictPrefKey:GENERAL_DICT];
	if(aObj != nil){
		[mGeneralItem recoverInf:aObj];
	}

	//アカウント情報を復元する
	aObj = [Misc readDataPrefKey:ACCOUNT_ITEM];
	if(aObj != nil){
		[mAccountItemArray autorelease];
		mAccountItemArray = [aObj retain];
	}

	//起動時に実行の判断
	if([mGeneralItem goAtStart]){
		[mAppController performGoButton];
	}

	//巡回用タイマーの発生
	[NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(timerProc:) userInfo:nil repeats:YES];
	
	//tls用のレジューム時チェック
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver: self 
		selector: @selector(receiveWakeNotification:) 
		name: NSWorkspaceDidWakeNotification object: NULL];
	
	// for growl
//	[GrowlApplicationBridge setGrowlDelegate:self];
	NSDictionary *note = [self registrationDictionaryForGrowl];
	[GrowlApplicationBridge registerWithDictionary:note];
	[GrowlApplicationBridge registerWithDictionary:note];	// 何故か二回叩かないとGrowlに登録されない。	
}

//操作ボタンが押されたときに呼ばれる
- (IBAction)buttonOperation:(id)sender
{
	switch([sender tag]){
	case GeneralButton_TAG: //巡回の設定...
		[self setupGeneralSheet];
		[self sheetOperation:mGeneralSheet];
		break;

	case EditButton_TAG: //編集...
		mEditAccount = [self accountItem:[mTableView selectedRow]];
		if(mEditAccount != nil){
			mAppendAcc = NO;
			[self setupAccountSheet];
			[self sheetOperation:mAccountSheet];
		}
		break;

	case DeleteButton_TAG: //削除...
		[self deleteAccountProc];
                //anne
                [mAppController updateAccountMenu];
		break;

	case ToTopButton_TAG: //このアカウントを先頭にする
		[self toTopAccountProc];
                //anne
                [mAppController updateAccountMenu];
		break;

	case StopWalkButton_TAG: //一時的な巡回中止
		[self walkAccountProc:YES];
		break;

	case ReWalkButton_TAG: //巡回を再開
		[self walkAccountProc:NO];
		break;

	case AppendAccButton_TAG: //新規アカウントを追加...
		mAppendAcc = YES;
		mEditAccount = [[AccountItem alloc] init];
		[mEditAccount setAccountID:[Misc newAccountID]];
		[self setupAccountSheet];
		[self sheetOperation:mAccountSheet];
		break;
	}
}

//巡回可能なアカウントがあるかを確認する
//戻り値=YESならある,NOならない
- (BOOL)hasWalkableAccount
{
	AccountItem *aObj;
	NSEnumerator *aItr = [mAccountItemArray objectEnumerator];
	while((aObj = [aItr nextObject]) != nil){
		if(![aObj notUse]){
			return YES;
		}
	}
	return NO;
}

//アカウント配列のイテレータをえる
- (NSEnumerator *)accountItemIterator
{
	return [mAccountItemArray objectEnumerator];
}

//新規メールがあることを音声で伝える(ただし選択されているときのみ)
- (void)speakNewMail
{
	if([mGeneralItem newMailVoiceEnable]){
		[mNewMailVoice_TV setString:[mGeneralItem newMailVoiceText]];
		[mNewMailVoice_TV startSpeaking:self];
	}
}

//エラーがあることを音声で伝える(ただし選択されているときのみ)
- (void)speakError
{
	if([mGeneralItem errorVoiceEnable]){
		[mErrorVoice_TV setString:[mGeneralItem errorVoiceText]];
		[mErrorVoice_TV startSpeaking:self];
	}
}

//新規メールがあることを音で伝える(ただし選択されているときのみ)
- (void)notifyNewMailBySound
{
	if([mGeneralItem newMailSoundEnable]){
		[mNewMailSound_TF setStringValue:[mGeneralItem newMailSoundPath]];
		NSSound *snd = [[NSSound alloc] initWithContentsOfFile:[mGeneralItem newMailSoundPath] byReference:YES];
		[snd play];
		[snd release];	// 明示して開放すべきモノ？
	}
}

//エラーがあることを声で伝える(ただし選択されているときのみ)
- (void)notifyErrorBySound
{
	if([mGeneralItem errorSoundEnable]){
		[mErrorSound_TF setStringValue:[mGeneralItem errorSoundPath]];
		NSSound *snd = [[NSSound alloc] initWithContentsOfFile:[mGeneralItem errorSoundPath] 
							byReference:YES];
		[snd play];
		[snd release];	// deallocだとEXC_BAD_ACCESSになっちゃう
	}
}

//新規メールがあることをGrowlのウインドウで伝える(ただし選択されているときのみ)
- (void)notifyNewMailByGrowl : (NSMutableArray *)mPeepedItemArray
{
	if([mGeneralItem newMailGrowlEnable])
	{
//		NSDictionary *regDict = [self registrationDictionaryFromDelegate];
//		NSDictionary * regDict = [GrowlApplicationBridge registrationDictionaryFromBundle: growlBundle];
//		[GrowlApplicationBridge registerWithDictionary:regDict];
		
		NSBundle *myBundle = [NSBundle bundleForClass:[PrefController class]];
		NSString *growlPath = [[myBundle privateFrameworksPath] 
							   stringByAppendingPathComponent:@"Growl.framework"];
		NSBundle *growlBundle = [NSBundle bundleWithPath:growlPath];
		
		if (growlBundle && [growlBundle load]) 
		{
//			NSDictionary *note = [self registrationDictionaryForGrowl];
//			NSLog(@"Working with %@",note);
//		[GrowlApplicationBridge registerWithDictionary:note];
//		[GrowlApplicationBridge reregisterGrowlNotifications];
//		[GrowlApplicationBridge notifyWithDictionary:note];

			// Register ourselves as a Growl delegate
			[GrowlApplicationBridge setGrowlDelegate:self];		// ここがネックだったみたい。
			NSUInteger mailNum = [mPeepedItemArray count];
			int cnt;
			for(cnt=0; cnt < mailNum; cnt++)
			{
				PeepedItem* pi = [mPeepedItemArray objectAtIndex:cnt];
				[GrowlApplicationBridge notifyWithTitle: [pi from]			//長いと適度な所で文字列は切れる
											description: [pi subject]		//文字列の最後まで出るみたい
									   notificationName: @"mailpeeper"		//登録した名前と合わせる
											   iconData: nil				//GROWL_NOTIFICATION_ICON
											   priority: 0					//GROWL_NOTIFICATION_PRIORITY
											   isSticky: NO					//GROWL_NOTIFICATION_STICKY
										   clickContext: [NSDate date]		//GROWL_NOTIFICATION_CLICK_CONTEXT
											 identifier: nil				//				 
				];
				
			} 
			
		}else{
			NSLog(@"ERROR: Could not load Growl.framework");
		}
		
		[myBundle release];
		[growlPath release];
		[growlBundle release];
	}
}


@end

@implementation PrefController(Private)

//「編集...」「新規アカウントを追加」「巡回の設定...」ボタンの反応としてシート表示を開始する
//iSheet=表示しようとするシート
- (void)sheetOperation:(NSWindow *)iSheet
{
	//巡回中なら反応しない
	if([mAppController usingWorkerThread]){
		return;
	}

	//シート表示開始
	[NSApp beginSheet:iSheet modalForWindow:mPrefPanel modalDelegate:nil didEndSelector:(SEL)0 contextInfo:NULL];
}

//「巡回の設定...」シートで決定ボタンを押されたときに呼ばれる
//戻り値=YESなら設定変更をし、シートを閉じるべし,NOなら継続せよ
- (BOOL)pressedGeneralOK
{
	GeneralItem_rec_t aRec;

	aRec.mGoAtStart = ([mGoAtStart_CB intValue] != 0);				//(プログラム起動時に巡回開始)
	aRec.mRepeat = ([mRepeat_CB intValue] != 0);					//(定期的に巡回するならYES)
	aRec.mRepeatMinute = [mRepeat_TF intValue];						//(巡回する間隔)
	aRec.mNewMailVoiceEnable = ([mNewMailVoice_CB intValue] != 0);	//(新規メールを音声で知らせる)
	aRec.mNewMailVoiceText = [mNewMailVoice_TV string];				//(新規メールを知らせる音声データ)
	aRec.mErrorVoiceEnable = ([mErrorVoice_CB intValue] != 0);		//(エラーを音声で知らせる)
	aRec.mErrorVoiceText = [mErrorVoice_TV string];					//(エラーを知らせる音声データ)
	
	aRec.mGoAtResume = ([mGoAtResume_CB intValue] != 0);			//(レジューム時に巡回するならYES)
	aRec.mNewMailSoundEnable = ([mNewMailSound_CB intValue] != 0);	//(着信音で知らせる)
	aRec.mNewMailSoundPath = [mNewMailSound_TF stringValue];		//(着信を知らせる音データ)
	aRec.mErrorSoundEnable = ([mErrorSound_CB intValue] != 0);		//(エラー声で知らせる)
	aRec.mErrorSoundPath = [mErrorSound_TF stringValue];			//(エラーを知らせる音データ)
	aRec.mNewMailGrowlEnable = ([mNewMailGrowl_CB intValue] != 0);	//(着信音で知らせる)
	
	if([mGeneralItem change:&aRec]){
		//Pref書類を更新する
		[Misc writeDictPref:[mGeneralItem saveInf] key:GENERAL_DICT];
		return YES;
	}else{
		NSRunCriticalAlertPanel(nil,NSLocalizedString(@"GENERAL_SHEET_NG",@""),nil,nil,nil);
		return NO;
	}
}

//アカウントシートで決定ボタンを押されたときに呼ばれる
//戻り値=YESなら設定変更をし、シートを閉じるべし,NOなら継続せよ
- (BOOL)pressedAccountOK
{
	NSString *aMsg;
	AccountItem_record_t aRec;
	AccountItem_change_t aChg;
	NSString *aAccName = [[self accountFormCell:AccountName_Index] stringValue];

	//アカウント名がすでに存在しているものかを確認する。存在しているならNG
	if([self checkAccountNameRegist:aAccName except:mEditAccount]){
		aMsg = [NSString stringWithFormat:NSLocalizedString(@"ACNG_REGISTERD",@""),aAccName];
		NSRunCriticalAlertPanel(nil,aMsg,nil,nil,nil);
		return NO;
	}

	//対象アカウントの変更および検証
	aRec.mAccountName = (NSMutableString *)aAccName;
	aRec.mPop3Server = (NSMutableString *)[[self accountFormCell:PopName_Index] stringValue];
	aRec.mPortNo = [[self accountFormCell:PortNo_Index] intValue];
	aRec.mUserName = (NSMutableString *)[[self accountFormCell:UserName_Index] stringValue];
	aRec.mPassWord = (NSMutableString *)[mPassword_TF stringValue];
	aRec.mTLS = [mTls_CB intValue];
	aChg = [mEditAccount change:&aRec];
	//検証が失敗したなら戻る
	if(aChg != AIC_OK){
		switch(aChg){
		case AIC_Account: //アカウント名がNG
			aMsg = NSLocalizedString(@"ACNG_ACCOUNT",@"");
			break;

		case AIC_Pop3: //POP3サーバー名がNG
			aMsg = NSLocalizedString(@"ACNG_POP3",@"");
			break;

		case AIC_PortNo: //ポート番号がNG
			aMsg = NSLocalizedString(@"ACNG_PORTNO",@"");
			break;

		case AIC_UserName: //ユーザー名がNG
			aMsg = NSLocalizedString(@"ACNG_USERNAME",@"");
			break;

		case AIC_PassWord: //パスワードがNG
			aMsg = NSLocalizedString(@"ACNG_PASSWORD",@"");
			break;

		default: //(本来はここを通過するのは変だが念のため)
			aMsg = NSLocalizedString(@"ACNG_UNKNOWN",@"");
			break;
		}
		NSRunCriticalAlertPanel(nil,aMsg,nil,nil,nil);
		return NO;
	}

	//ここまできたなら、ひとまずOK
	
	//新規追加なら追加処理
	if(mAppendAcc){
		[mAccountItemArray addObject:mEditAccount];
		//UIも影響を受けるので更新する
		//テーブルビューの表示更新
		[mTableView reloadData];
		//テーブルビューの選択を追加したコラムにする
		[mTableView selectColumnIndexes:([mTableView selectedColumnIndexes]) byExtendingSelection:NO];
		
		[self updateUI];
	}

	//Pref書類を更新する
	[Misc writeDataPref:mAccountItemArray key:ACCOUNT_ITEM];

	return YES;
}

//「巡回の設定...」シートを表示する前に、その中身を準備する
- (void)setupGeneralSheet
{
	[mGoAtStart_CB setIntValue:[mGeneralItem goAtStart]];
	[mRepeat_CB setIntValue:[mGeneralItem repeat]];
	[mRepeat_TF setIntValue:[mGeneralItem repeatMinute]];
	[mNewMailVoice_CB setIntValue:[mGeneralItem newMailVoiceEnable]];
	[mNewMailVoice_TV setString:[mGeneralItem newMailVoiceText]];
	[mErrorVoice_CB setIntValue:[mGeneralItem errorVoiceEnable]];
	[mErrorVoice_TV setString:[mGeneralItem errorVoiceText]];
	
	[mGoAtResume_CB setIntValue:[mGeneralItem goAtResume]];
	[mNewMailSound_CB setIntValue:[mGeneralItem newMailSoundEnable]];
	[mNewMailSound_TF setStringValue:[mGeneralItem newMailSoundPath]];
	[mErrorSound_CB setIntValue:[mGeneralItem errorSoundEnable]];
	[mErrorSound_TF setStringValue:[mGeneralItem errorSoundPath]];
	[mNewMailGrowl_CB setIntValue:[mGeneralItem newMailGrowlEnable]];
}

//アカウントシートを表示する前に、その中身を準備する
- (void)setupAccountSheet
{
	[[self accountFormCell:AccountName_Index] setObjectValue:[mEditAccount accountName]];
	[[self accountFormCell:PopName_Index] setObjectValue:[mEditAccount pop3Server]];
	[[self accountFormCell:PortNo_Index] setObjectValue:[NSNumber numberWithInt:[mEditAccount portNo]]];
	[[self accountFormCell:UserName_Index] setObjectValue:[mEditAccount userName]];
	[mPassword_TF setStringValue:[mEditAccount passWord]];
	[mTls_CB setObjectValue:[NSNumber numberWithInt:[mEditAccount tls]]];
}

//アカウントシート上のフォームセルをえる
//iIndex=インデックス
- (NSFormCell *)accountFormCell:(int)iIndex
{
	return [mAccountForm cellAtIndex:iIndex];
}

//アカウント名がすでに登録済みかを確認する
//iName=アカウント名,iExcept=このオブジェクトはよける
//戻り値=YESなら登録済み,NOならまだ
- (BOOL)checkAccountNameRegist:(NSString *)iName except:(AccountItem *)iExcept
{
	AccountItem *aObj;
	NSEnumerator *aItr = [mAccountItemArray objectEnumerator];
	while((aObj = [aItr nextObject]) != nil){
		if(aObj != iExcept && [[aObj accountName] isEqualToString:iName]){
			return YES;
		}
	}
	return NO;
}

//指定インデックスのアカウントオブジェクトをえる
//インデックスが範囲外ならnilを返す
- (AccountItem *)accountItem:(int)iIndex
{
	return (iIndex < 0 || iIndex >= [mAccountItemArray count]) ? nil : [mAccountItemArray objectAtIndex:iIndex];
}

//選択されたアカウントの削除処理
- (void)deleteAccountProc
{
	int aSelectedRow = [mTableView selectedRow]; //テーブルビューの選択されている行

	if(aSelectedRow >= 0){
		int aRes;
		AccountItem *aItem = [self accountItem:aSelectedRow]; //選択されているアカウント情報
		
		//削除していいかを尋ねる
		aRes = NSRunAlertPanel(NSLocalizedString(@"DEL_ACCOUNT_TITLE",@"タイトル"),
							   [NSString stringWithFormat:NSLocalizedString(@"DEL_ACCOUNT_QUESTION",@""),
														  [aItem accountName]],
							   NSLocalizedString(@"DEL_ACCOUNT_NO",@"中止します(default)"),
							   NSLocalizedString(@"DEL_ACCOUNT_YES",@"削除します(alt.)"),
							   nil);
		if(aRes == NSAlertAlternateReturn){
			//削除処理
			//アカウント配列から削除
			[mAccountItemArray removeObjectAtIndex:aSelectedRow];
			//Pref書類を更新する
			[Misc writeDataPref:mAccountItemArray key:ACCOUNT_ITEM];
			//表示を更新する
			[mTableView reloadData];
			[self updateUI];
		}
	}
}

//選択されたアカウントを先頭に移動する
- (void)toTopAccountProc
{
	int aSelectedRow = [mTableView selectedRow]; //テーブルビューの選択されている行

	if(aSelectedRow > 0){
		AccountItem *aItem = [self accountItem:aSelectedRow]; //選択されているアカウント情報
		//アカウントを先頭に挿入する
		[mAccountItemArray insertObject:aItem atIndex:0];
		//元の位置(挿入によって+1ずれている)の情報を削除する
		[mAccountItemArray removeObjectAtIndex:aSelectedRow + 1];
		//Pref書類を更新する
		[Misc writeDataPref:mAccountItemArray key:ACCOUNT_ITEM];
		//表示を更新する
		[mTableView reloadData]; //テーブルビューの表示更新
		[mTableView selectColumnIndexes:0 byExtendingSelection:NO];	//テーブルビューの選択を先頭にする
		[self updateUI];
	}
}

//選択されたアカウントの巡回停止,再開をさせる
//iStop=YESなら停止,NOなら再開
- (void)walkAccountProc:(BOOL)iStop
{
	AccountItem *aItem = [self accountItem:[mTableView selectedRow]]; //選択されているアカウント情報

	if(aItem != nil){
		[aItem setNotUse:iStop];
		//表示を更新する
		[mTableView reloadData]; //テーブルビューの表示更新
		[self updateUI];
	}
}

//タイマー処理(1分単位)
- (void)timerProc:(NSTimer *)iTimer
{
	//NSLog(@"PrefController.timerProc");

	if([mGeneralItem repeat]){
		//定期巡回をするなら、カウンターを1つ増やし、時間が来たなら巡回処理をする
		if(++mRepeatTimer >= [mGeneralItem repeatMinute]){
			[mAppController performGoButton];
			//カウンターをリセットする
			mRepeatTimer = 0;
		}
	}
}

//レジューム時にメールチェックする
- (void)receiveWakeNotification:(NSNotification *)notification 
{
	sleep(10);	//ネットワークがつながってから動く対策（本当はマシな確認をすべき）
	//メールチェックする
	if([mGeneralItem goAtResume])
	{
		[mAppController performGoButton];
		//カウンターをリセットする
		mRepeatTimer = 0;		
	}
}

	
#define APPLICATION_NAME @"mailpeeper"
	
	//Return the registration dictionary
- (NSDictionary *)registrationDictionaryForGrowl
{
	NSMutableArray *defNotesArray = [NSMutableArray array];
	NSMutableArray *allNotesArray = [NSMutableArray array];
	NSMutableArray *applicationArray = [NSMutableArray array];
	
	[allNotesArray addObject:APPLICATION_NAME];
	[defNotesArray addObject:APPLICATION_NAME];	
	[applicationArray addObject:@"mailpeeper-tls"];
	
	//Set these notifications both for ALL (all possibilites) and DEFAULT (the ones enabled by default)
	NSDictionary *regDict = [NSDictionary dictionaryWithObjectsAndKeys:
							 @"mailpeeper-tls", GROWL_APP_NAME,
							 allNotesArray, GROWL_NOTIFICATIONS_ALL,
							 defNotesArray, GROWL_NOTIFICATIONS_DEFAULT,
							 nil];
	
	NSLog(@"Registering with %@",regDict);
	return regDict;
}
	
	

@end

// End Of File
