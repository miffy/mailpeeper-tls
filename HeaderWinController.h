//
//  HeaderWinController.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/16-09/16.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AppController;
@class PeepedItem;

@interface HeaderWinController : NSObject {
	//(アウトレット)
	IBOutlet NSWindow *mWindow; 		//表示ウィンドウ
	IBOutlet NSTextView *mTextView;		//表示ビュー

	//(アウトレット以外)
	AppController *mAppController;	//アプリケーションコントローラー
	int mAccountID;					//アカウントID
	NSString *mUID;					//UID(UIDLでえた情報)
	BOOL mDeleted;					//削除フラグ,これがYESならゴミになっている
}

- (id)initWithAppController:(AppController *)iAppCtl peepedItem:(PeepedItem *)iPeepItem;
- (BOOL)isEqualToPeepedItem:(PeepedItem *)iItem;
- (void)showFront;
- (BOOL)deleted;

@end

// End Of File
