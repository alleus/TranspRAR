//
//  ACArchiveEntry.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import "ACArchiveEntry.h"


@implementation ACArchiveEntry

@synthesize parserDictionary;
@synthesize parser;
@synthesize handle;
@synthesize archive;

- (void)dealloc {
	[attributes release];
	attributes = nil;
	[parserDictionary release];
	parserDictionary = nil;
	[parser release];
	parser = nil;
	[handle release];
	handle = nil;
	archive = nil;
	
	[super dealloc];
}

- (NSMutableDictionary *)attributes {
	if (!attributes) {
		attributes = [[NSMutableDictionary alloc] init];
		[attributes setObject:[parserDictionary objectForKey:XADFileSizeKey] forKey:NSFileSize];
		[attributes setObject:[parserDictionary objectForKey:XADLastModificationDateKey] forKey:NSFileModificationDate];
		if ([[parserDictionary objectForKey:XADIsDirectoryKey] boolValue]) {
			[attributes setObject:NSFileTypeDirectory forKey:NSFileType];
		} else {
			[attributes setObject:NSFileTypeRegular forKey:NSFileType];
		}
	}
	return attributes;
}

@end
