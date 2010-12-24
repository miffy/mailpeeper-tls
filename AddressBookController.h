//
//  AddressBookController.h
//  MailPeeper
//
//  Created by anne on Wed Feb 19 2003.
//  Copyright (c) 2003 by anne. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ABGroup;
@class ABPerson;

@interface AddressBookController : NSObject {
    NSMutableArray *group;
    ABGroup *currentGroup;
    NSMenu *groupMenu;
    IBOutlet id statusBarMenu;

}
- (IBAction) updateMenu:(id)sender;
- (void) createMenu;
- (NSMenu *) makeAddressMenu;
- (NSMutableArray *)listGroup;
- (void) setGroup:(NSMutableArray *)aGroup;
- (NSMutableArray *)group;
- (void) setGroupMenu:(NSMenu *)aMenu;
- (NSMenu *) groupMenu;
- (void) addMailMenu:(id)obj menuItem:(NSMenuItem *)personItem;
- (void) addNameMenu:(id)obj menu:(NSMenu *)memberMenu;
- (void) newMail:(id)sender;


@end
