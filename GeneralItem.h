//
//  GeneralItem.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/13-10/04.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
	BOOL mGoAtStart;				//プログラム起動時に巡回開始ならYES
	BOOL mRepeat;					//定期的に巡回するならYES
	int mRepeatMinute;				//巡回する間隔(分)
	BOOL mNewMailVoiceEnable;		//新規メールを音声で知らせるならYES
	NSString *mNewMailVoiceText;	//新規メールを知らせる音声データ
	BOOL mErrorVoiceEnable;			//エラーを音声で知らせるならYES
	NSString *mErrorVoiceText;		//エラーを知らせる音声データ
} GeneralItem_rec_t;

@interface GeneralItem : NSObject /* <NSCoding> */ {	//一般設定
	//(記録対象フィールド)
	GeneralItem_rec_t mR;

	//(記録対象外フィールド)
}
- (void)recoverInf:(id)iInf;
- (id)saveInf;

- (BOOL)change:(GeneralItem_rec_t *)iData;
- (BOOL)goAtStart;
- (BOOL)repeat;
- (int)repeatMinute;
- (BOOL)newMailVoiceEnable;
- (NSString *)newMailVoiceText;
- (BOOL)errorVoiceEnable;
- (NSString *)errorVoiceText;

@end

// End Of File
