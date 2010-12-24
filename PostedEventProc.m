//
//  PostedEventProc.m
//  MailPeeper
//
//  Created by Dentom on 2002/10/06.
//  Copyright (c) 2002 by Dentom. All rights reserved.
//

#import "PostedEventProc.h"
#import "PeepedItem.h"
#import "AppController.h"

@implementation PostedEventProc

- (void)performAppController:(AppController *)iAppController
{
	NSLog(@"PostedEventProc.performAppController (ERROR)");
}

@end

@implementation NewMailProc

- (id)initWithPeepedItem:(PeepedItem *)iItem no:(int)iNo
{
	if((self = [super init]) != nil){
		mItem = [iItem retain];
		mNo = iNo;
	}
	return self;
}

- (void)performAppController:(AppController *)iAppController
{
	[iAppController appendNewMail:mItem pos:mNo];
}

- (void)dealloc
{
	[mItem autorelease];
	
	[super dealloc];
}

@end

@implementation ReportErrProc

- (id)initWithErr:(BOOL)iErr newMail:(BOOL)iNewMail
{
	if((self = [super init]) != nil){
		mErr = iErr;
		mNewMail = iNewMail;
	}
	return self;
}

- (void)performAppController:(AppController *)iAppController
{
	[iAppController reportErr:mErr newMail:mNewMail];
}

@end

@implementation DispStatusProc

- (id)initWithMessage:(NSString *)iMessage red:(BOOL)iRed
{
	if((self = [super init]) != nil){
		mMessage = [iMessage retain];
		mRed = iRed;
	}
	return self;
}

- (void)performAppController:(AppController *)iAppController
{
	if(mRed){
		[iAppController dispStatusRed:mMessage];
	}else{
		[iAppController dispStatusBlack:mMessage];
	}
}

- (void)dealloc
{
	[mMessage autorelease];
	
	[super dealloc];
}

@end

@implementation ChangeThreadStatus

- (id)initWithBegin:(BOOL)iBegin
{
	if((self = [super init]) != nil){
		mBegin = iBegin;
	}
	return self;
}

- (void)performAppController:(AppController *)iAppController
{
	[iAppController updateUIforThread:mBegin];
}

@end

// End Of File
