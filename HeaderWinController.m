//
//  HeaderWinController.m
//  MailPeeper
//
//  Created by Dentom on 2002/09/16-09/16.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//
//  Modifired by anne

#import "HeaderWinController.h"
#import "PeepedItem.h"

/*@interface HeaderWinController(Private)

@end*/

@implementation HeaderWinController

//初期化メソッド
- (id)initWithAppController:(AppController *)iAppCtl peepedItem:(PeepedItem *)iPeepItem
{
	if((self = [super init]) != nil){
		//内部変数の準備
		mAppController = iAppCtl;
		mAccountID = [iPeepItem accountID];
		mUID = [[iPeepItem uid] retain];
		
		//ウィンドウを開く
		if([NSBundle loadNibNamed:@"HeaderWin" owner:self]){
			[mWindow setTitle:[iPeepItem subject]];
			[mTextView setString:[iPeepItem allHeader]];
			[mWindow center];
                        
                        //anne
                        [NSApp activateIgnoringOtherApps: YES];
                        
			[mWindow makeKeyAndOrderFront:self];
		}
	}
	return self;
}

//終了化メソッド
- (void)dealloc
{
	//NSLog(@"HeaderWinController.dealloc");

	[mWindow release];
	[mUID release];

	[super dealloc];
}

//指定アイテムと同じアカウントID,UIDを持っているならYESを返す
- (BOOL)isEqualToPeepedItem:(PeepedItem *)iItem
{
	return (mAccountID == [iItem accountID]) && [mUID isEqualToString:[iItem uid]];
}

//ウィンドウを前に出す
- (void)showFront
{
	[mWindow makeKeyAndOrderFront:self];
}

//(ウィンドウからのデリゲート)
//ウィンドウが閉じようとするときに呼ばれる
- (void)windowWillClose:(NSNotification *)aNotification
{
	//削除フラグを立てる
	mDeleted = YES;
}

//削除フラグをえる
- (BOOL)deleted
{
	return mDeleted;
}

@end

/*@implementation HeaderWinController(Private)

@end*/

// End Of File
