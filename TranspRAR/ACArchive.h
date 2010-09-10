//
//  ACArchive.h
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACArchiveEntry.h"


@interface ACArchive : NSObject {
	NSMutableDictionary		*entries;
}

- (ACArchiveEntry *)entryWithFilename:(NSString *)filename;
- (NSArray *)entryFilenames;

@end
