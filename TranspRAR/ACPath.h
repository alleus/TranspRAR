//
//  ACPath.h
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACArchive.h"


@interface ACPath : NSObject {
	NSMutableDictionary		*archives;
}

- (void)addArchive:(ACArchive *)archive withFilename:(NSString *)filename;
- (ACArchive *)archiveWithFilename:(NSString *)filename;
- (ACArchiveEntry *)entryWithFilename:(NSString *)filename;

@end
