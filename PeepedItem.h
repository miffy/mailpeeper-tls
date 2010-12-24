//
//  PeepedItem.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-09/17.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PeepedItem : NSObject <NSCoding> {	//メール受信結果を保持するクラス
	//(記録対象フィールド)
	int mAccountID;					//アカウントID
	NSString *mUID;					//UID(UIDLでえた情報)
	int mMailSize;					//メールのサイズ
	NSMutableArray *mHeadArray;		//ヘッダー情報 (NSDataオブジェクト配列)
	NSString *mFrom;				//From:情報
	NSString *mSubject;				//Subject:情報
	NSString *mDate;				//Date:情報

	//(記録対象外フィールド)
	BOOL mSaveFlag;					//保存フラグ(保存対象ならYES)
	BOOL mNewMailFlag;				//新規メールならYES
}

- (void)setAccountID:(int)iID;
- (int)accountID;
- (void)setMailSize:(int)iSize;
- (int)mailSize;
- (void)appendTOPdata:(NSData *)iData;
- (void)analizeHeader;
- (NSString *)uid;
- (void)setUID:(NSString *)iUID;
- (NSString *)from;
- (NSString *)subject;
- (NSString *)date;
- (NSString *)allHeader;
- (NSString *)newMailMark;
- (void)setSaveFlag:(BOOL)iFlag;
- (BOOL)saveFlag;
- (void)setNewMailFlag:(BOOL)iFlag;
- (NSString *)newMailMark;

@end

// End Of File
