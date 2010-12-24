//
//  AddressBookController.m
//  MailPeeper
//
//  Created by anne on Wed Feb 19 2003.
//  Copyright (c) 2003 by anne. All rights reserved.
//

#import "AddressBookController.h"
#import <AddressBook/AddressBook.h>

static NSString *mailto = @"mailto:";
//account menuを挿入する一つ上のセパレータのタグ
static int TAG = 101;
//address menuのタグ。作成する時に付加し、削除する時に参照
static int ADDRESS_TAG = 102;


@implementation AddressBookController

-(void)dealloc{
    [group release];
    [currentGroup release];
    [groupMenu release];
    [super dealloc];
}

- (id) init
{
    if((self = [super init]) != nil){
            [self setGroup:[self listGroup]];
            //NSLog(@"initialize AddressBookController");
    }
	return self;
}


- (void)awakeFromNib
{
    [self createMenu];
}


- (IBAction) updateMenu:(id)sender
{
    [self createMenu];
}

- (void) createMenu
{
    if (groupMenu) {
        // find where to delete the item
        id item;
        int deleteIndex = 0;
        NSEnumerator *enumerator = [[statusBarMenu itemArray] objectEnumerator];
        while (item = [enumerator nextObject]) {
            if ([item tag] == ADDRESS_TAG) {
                deleteIndex = [statusBarMenu indexOfItem:item];
            }
        }
        [statusBarMenu removeItemAtIndex:deleteIndex];
    }
    [self setGroupMenu:[self makeAddressMenu]];
    //NSLog(@"update groupMenu");
    
    NSMenuItem *newItem;
    newItem = [[NSMenuItem alloc] init];
    [newItem setTitle:@"Address"];
    [newItem setTag:ADDRESS_TAG];
    [newItem setSubmenu:[self groupMenu]];
    
    // find where to add the item
    id item;
    int insertIndex = 0;
    NSEnumerator *enumerator = [[statusBarMenu itemArray] objectEnumerator];
    while (item = [enumerator nextObject]) {
        if ([item tag] == TAG) {
            insertIndex = [statusBarMenu indexOfItem:item] + 1;
        }
    }
    
    [statusBarMenu insertItem:newItem atIndex:insertIndex];
    [newItem release];
}

- (NSMenu *) makeAddressMenu
{
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    
    NSMenu *newMenu = [[[NSMenu alloc] initWithTitle:@"newItemTitle"] autorelease];
    
    NSEnumerator *enumerator = [group objectEnumerator];
    id object;
    int indexOfGroup = 0;
    while (object = [enumerator nextObject]) {
        NSMenuItem *groupItem = [[NSMenuItem alloc] initWithTitle:[object description] action:NULL keyEquivalent:@""];
        [newMenu addItem:groupItem];
        
        //とりあえずサブメニュー化
        NSMenu *memberMenu = [[NSMenu alloc] initWithTitle:@""];
        [groupItem setSubmenu:memberMenu];
        
        //NSLog(@"%d",indexOfGroup);
        if (!indexOfGroup) {
            NSArray *member = [[[NSArray alloc] init] autorelease];
            member = [ab people];
            //NSLog(@"%@",members);
            NSEnumerator *person = [member objectEnumerator];
            id obj;
            while ((obj = [person nextObject]) != nil) {
                //name,mailのメニューを追加
                //NSString *name = nil;
                [self addNameMenu:obj menu:memberMenu];
            }
            
        } else {
            //NSLog(@"%d",indexOfGroup);
            NSArray *everyGroup = [[[NSArray alloc] init] autorelease];
            everyGroup = [ab groups];
            ABGroup *mGroup = [everyGroup objectAtIndex:indexOfGroup -1];
            //NSLog(@"%@",[mGroup members]);kABFirstNameProperty
            NSArray *member = [[[NSArray alloc] init] autorelease];
            member = [mGroup members];
            
            
            NSEnumerator *person = [member objectEnumerator];
            id obj;
            while ((obj = [person nextObject]) != nil) {
                //name,mailのメニューを追加
                //NSString *name = nil;
                [self addNameMenu:obj menu:memberMenu];            }
        }//if (!indexOfGroup)
        
        indexOfGroup ++;
        [groupItem release];
    }//while (object = [enumerator nextObject])
    
    return newMenu;
}


- (void) addNameMenu:(id)obj menu:(NSMenu *)memberMenu
{
    NSMutableString *name = [[[NSMutableString alloc] initWithString:@" "] autorelease];
    
    if ([obj valueForProperty:kABFirstNameProperty]){
        if ([obj valueForProperty:kABLastNameProperty]){
            [name insertString:[obj valueForProperty:kABFirstNameProperty] atIndex:0];
            [name appendString:[obj valueForProperty:kABLastNameProperty]];
	} else {
            name = [obj valueForProperty:kABFirstNameProperty];
	}
    } else {
	if ([obj valueForProperty:kABLastNameProperty]){
            name = [obj valueForProperty:kABLastNameProperty];
	}
    }

    if (name){
	NSMenuItem *personItem = [[NSMenuItem alloc] initWithTitle:name action:NULL keyEquivalent:@""];
	[memberMenu addItem:personItem];

	[self addMailMenu:obj menuItem:personItem];
	[personItem release];
    }/*if (name)*/
}

- (void) addMailMenu:(id)obj menuItem:(NSMenuItem *)personItem
{
    //emailを追加
    if ([obj valueForProperty:kABEmailProperty]){
        NSMenu *mailMenu = [[NSMenu alloc] initWithTitle:@""];
	[personItem setSubmenu:mailMenu];
	
        int index;
	for (index = 0; index < [[obj valueForProperty:kABEmailProperty] count]; index++) {
	//NSLog(@"%@",[[obj valueForProperty:kABEmailProperty] valueAtIndex:index]);
        NSString *mail = [[obj valueForProperty:kABEmailProperty] valueAtIndex:index];
        
	//NSMenuItem *mailItem = [[NSMenuItem alloc] initWithTitle:mail action:newMailSelector keyEquivalent:@""];
        NSMenuItem *mailItem = [[NSMenuItem alloc] init];
        [mailItem setTitle:mail];
        [mailItem setTarget:self];
        [mailItem setAction:@selector(newMail:)];
        
        
        [mailMenu addItem:mailItem];
	[mailItem release];
        }/* for */
	//NSLog(@"%d",[[obj valueForProperty:kABEmailProperty] count]);
	//NSLog(@"%@",[[obj valueForProperty:kABEmailProperty] valueAtIndex:0]);
    }/*if ([obj valueForProperty:kABEmailProperty])*/
}


- (void) newMail:(id)sender
{
    NSMutableString *address = [NSMutableString stringWithString:mailto];
    [address appendString:[sender title]];
    
    id url = [ NSURL URLWithString: address];

    [ [ NSWorkspace sharedWorkspace ] openURL: url ];
    return ;
}

- (NSMutableArray *)listGroup
{
    NSArray *everygroup = [[[NSArray alloc] init] autorelease];
    NSMutableArray *aGroup = [[[NSMutableArray alloc] init] autorelease];
    
    [aGroup addObject:@"All"];
    
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];

    everygroup = [ab groups];

    id obj;
    NSEnumerator *enumerator = [everygroup objectEnumerator];
    while ((obj = [enumerator nextObject]) != nil){
        ABGroup *someGroup = obj;
        [aGroup addObject:[someGroup valueForProperty:kABGroupNameProperty]];
    }
    
    return aGroup;
}/* listGroup*/

// ----------------------------------------------------------------------------------------
// アクセッサメソッド
// ----------------------------------------------------------------------------------------


- (void) setGroup:(NSMutableArray *)aGroup
{
    [aGroup retain];
    [group release];
    group = aGroup;
}/* setGroup */

- (NSMutableArray *)group
{
    return group;
}/* group */

- (void) setGroupMenu:(NSMenu *)aMenu
{
    [aMenu retain];
    [groupMenu release];
    //NSLog(@"release groupMenu");
    groupMenu = aMenu;
}

- (NSMenu *) groupMenu
{
    return groupMenu;
}

@end
