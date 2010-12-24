//
//  AccountItem.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-09/15.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct {
	NSMutableString *mAccountName; 	//アカウント名
	NSMutableString *mPop3Server;  	//POP3サーバー名
	int mPortNo;					//ポート番号
	NSMutableString *mUserName;		//ユーザー名
	NSMutableString *mPassWord;		//パスワード
	int mTLS;						//tlsを使うかどうか(暗号化の時に問題が出たので、boolを使うのはやめた)
} AccountItem_record_t;

typedef enum {
	AIC_OK,			//OK
	AIC_Account,	//アカウント名がNG
	AIC_Pop3,		//POP3サーバー名がNG
	AIC_PortNo,		//ポート番号がNG
	AIC_UserName,	//ユーザー名がNG
	AIC_PassWord	//パスワードがNG
} AccountItem_change_t;

@interface AccountItem : NSObject <NSCoding> {	//アカウント情報
	//(記録対象フィールド)
	AccountItem_record_t mR;		//編集対象フィールド
	int mAccountID;					//アカウントID

	//(記録対象外フィールド)
	BOOL mNotUse;					//YESなら巡回しない,NOで巡回する
}
- (NSString *)accountName;
- (NSString *)pop3Server;
- (unsigned short)portNo;
- (NSString *)userName;
- (NSString *)passWord;
- (AccountItem_change_t)change:(AccountItem_record_t *)iData;
- (BOOL)notUse;
- (void)setNotUse:(BOOL)iNotUse;
- (void)setAccountID:(int)iID;
- (int)accountID;
- (int)tls;
@end

// End Of File
