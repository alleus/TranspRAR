//
//  ACArchiveEntry.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import "ACArchiveEntry.h"
#import "ACArchive.h"


@implementation ACArchiveEntry

@synthesize filename;
@synthesize parserDictionary;
@synthesize handle;
@synthesize archive;

- (id)initWithFilename:(NSString *)aString {
	if ((self = [super init])) {
		self.filename = aString;
	}
	return self;
}

- (void)dealloc {
	[filename release];
	filename = nil;
	[attributes release];
	attributes = nil;
	[parserDictionary release];
	parserDictionary = nil;
	[handle release];
	handle = nil;
	archive = nil;

	[super dealloc];
}

- (void)closeHandle {
	ACLog(@"Closing archive entry handler for %@ in %@", filename, archive.path);
	[handle close];
	[handle release];
	handle = nil;
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

- (XADHandle *)handle {
	if (!handle) {
		@try {
			ACLog(@"Creating archive entry handler for %@ in %@", filename, archive.path);
			// Parse archive (if needed)
			[archive parse];
			// Create the handle
			handle = [[archive.parser handleForEntryWithDictionary:self.parserDictionary wantChecksum:NO] retain];
		}
		@catch (NSException * e) {
			NSLog(@" - Could not create archive entry handle for %@ in %@", filename, archive.path);
			NSLog(@" - Exception: %@, Reason: %@", [e name], [e reason]);
		}
	}
	return handle;
}

- (BOOL)handlePresent {
	return (handle != nil);
}

@end
