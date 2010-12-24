//
//  Misc.h
//  MailPeeper
//
//  Created by Dentom on 2002/09/12-09/27.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Misc : NSObject {

}
+ (BOOL)is_10_2_or_later_version;

+ (void)writeDataPref:(id)iObject key:(NSString *)iKey;
+ (id)readDataPrefKey:(NSString *)iKey;
+ (void)writeDictPref:(NSDictionary *)iDict key:(NSString *)iKey;
+ (NSDictionary *)readDictPrefKey:(NSString *)iKey;

+ (NSMutableString *)defaultMutableString:(NSString *)iKey;
+ (int)newAccountID;
+ (NSString *)dataToString:(NSData *)iData;

@end

char *strstr_touppered(const char *iText,const char *iSearch);

// End Of File
