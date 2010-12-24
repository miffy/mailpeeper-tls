//
//  SimpleFIFO.m
//
//  Created by Dentom on 2002/10/06.
//  Copyright (c) 2002 Dentom. All rights reserved.
//

#import "SimpleFIFO.h"

struct SimpleFIFO_Cell { //FIFOに格納されるセル
	struct SimpleFIFO_Cell *next; //次のセルを指す
	id object; //保持しているオブジェクト
};

@implementation SimpleFIFO

/*- (id)init
{
}*/

- (void)dealloc
{
	//FIFOを空読みする
	while([self pop] != nil){};
	
	[super dealloc];
}

//FIFOに格納されているオブジェクトの数をえる
- (unsigned int)count
{
	return mCellCount;
}

//FIFOの末尾にオブジェクトを格納する
//iObj=格納したいオブジェクト、retainされるので注意
- (void)push:(id)iObj
{
	struct SimpleFIFO_Cell *aCell;

	//nilオブジェクトは格納しない
	if(iObj == nil){
		return;
	}

	aCell = malloc(sizeof(struct SimpleFIFO_Cell));
	aCell->object = [iObj retain];
	aCell->next = NULL;
	
	if(mCellCount == 0){
		mCellTop = aCell;
	}else{
		mCellLast->next = aCell;
	}
	mCellLast = aCell;
	++mCellCount;
}

//FIFOの先頭からオブジェクトを取り出す。取り出すオブジェクトがないならnilを返す
//戻り値=取り出したオブジェクト or nil、autoreleaseされているので注意
- (id)pop
{
	id aAns;
	struct SimpleFIFO_Cell *aCell;

	//取り出すオブジェクトがないなら戻る
	if(mCellCount == 0){
		return nil;
	}

	aCell = mCellTop;
	mCellTop = aCell->next;
	aAns = aCell->object;
	free(aCell);
	--mCellCount;

	return [aAns autorelease];
}

@end

// End Of File
