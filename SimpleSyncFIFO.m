//
//  SimpleSyncFIFO.m
//
//  Created by Dentom on 2002/10/06.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import "SimpleSyncFIFO.h"

@implementation SimpleSyncFIFO

- (id)init
{
	if((self = [super init]) != nil){
		mLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[mLock release];
	
	[super dealloc];
}

//FIFOに格納されているオブジェクトの数をえる
- (unsigned int)count
{
	unsigned int aAns;
	
	[mLock lock];
	aAns = [super count];
	[mLock unlock];
	
	return aAns;
}

//FIFOの末尾にオブジェクトを格納する
//iObj=格納したいオブジェクト、retainされるので注意
- (void)push:(id)iObj
{
	[mLock lock];
	[super push:iObj];
	[mLock unlock];
}

//FIFOの先頭からオブジェクトを取り出す。取り出すオブジェクトがないならnilを返す
//戻り値=取り出したオブジェクト or nil、autoreleaseされているので注意
- (id)pop
{
	id aAns;

	[mLock lock];
	aAns = [super pop];
	[mLock unlock];

	return aAns;
}

//popと同じだが他のスレッドがアクセス中ならnilで、ただちに戻る
- (id)popEasy
{
	if([mLock tryLock]){
		id aAns = [super pop];
		[mLock unlock];
		return aAns;
	}else{
		return nil;
	}
}

@end

// End Of File
