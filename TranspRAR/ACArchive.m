//
//  ACArchive.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import "ACArchive.h"
#import <XADMaster/XADArchiveParser.h>


@implementation ACArchive

- (id)init {
	if ((self = [super init])) {
		entries = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc {
	[entries release];
	entries = nil;
	
	[super dealloc];
}

- (ACArchiveEntry *)entryWithFilename:(NSString *)filename {
	return [entries objectForKey:filename];
}

- (NSArray *)entryFilenames {
	return [entries allKeys];
}



-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {
	NSString *filename = [[dict objectForKey:XADFileNameKey] string];
	
	if (![entries objectForKey:filename]) {
		ACArchiveEntry *entry = [[ACArchiveEntry alloc] init];
		entry.parserDictionary = dict;
		entry.parser = parser;
		entry.archive = self;
		
		[entries setObject:entry forKey:filename];
		[entry release];
	}
}

@end
