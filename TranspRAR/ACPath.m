//
//  ACPath.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import "ACPath.h"


@implementation ACPath

- (id)init {
	if ((self = [super init])) {
		archives = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc {
	[archives release];
	archives = nil;
	
	[super dealloc];
}

- (void)addArchive:(ACArchive *)archive withFilename:(NSString *)filename {
	[archives setObject:archive forKey:filename];
}

- (ACArchive *)archiveWithFilename:(NSString *)filename {
	return [archives objectForKey:filename];
}

- (ACArchiveEntry *)entryWithFilename:(NSString *)filename {
	ACArchiveEntry *entry = nil;
	NSArray *archiveArray = [archives allValues];
	for (ACArchive *archive in archiveArray) {
		if ((entry = [archive entryWithFilename:filename])) {
			break;
		}
	}
	return entry;
}

@end
