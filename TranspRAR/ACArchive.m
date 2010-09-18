//
//  ACArchive.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import "ACArchive.h"
#import <XADMaster/XADArchiveParser.h>


@interface ACArchive ()

- (void)startParser;

@end


@implementation ACArchive

@synthesize path;
@synthesize parser;

#pragma mark -
#pragma mark Initialization and deallocation

- (id)initWithPath:(NSString *)aString {
	if ((self = [self init])) {
		self.path = aString;
	}
	return self;
}

- (id)init {
	if ((self = [super init])) {
		entries = [[NSMutableDictionary alloc] init];
		parserLock = [[NSLock alloc] init];
		parserTimeoutLock = [[NSConditionLock alloc] initWithCondition:0];
	}
	return self;
}

- (void)dealloc {
	[parserLock lock];
	[entries release];
	entries = nil;
	[parserLock unlock];
	[parserLock release];
	parserLock = nil;
	[parserTimeoutLock release];
	parserTimeoutLock = nil;
	[path release];
	path = nil;
	[parser release];
	parser = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Custom methods

- (ACArchiveEntry *)entryWithFilename:(NSString *)filename {
	[parserLock lock];
	ACArchiveEntry *returnEntry = [entries objectForKey:filename];
	[parserLock unlock];
	return returnEntry;
}

- (NSArray *)entryFilenames {
	[parserLock lock];
	NSArray *returnArray = [entries allKeys];
	[parserLock unlock];
	return returnArray;
}

- (BOOL)parse {
	if (!hasParsed) {
		ACLog(@" - Parsing...");
		NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:10.0];
		
		[self performSelectorInBackground:@selector(startParser) withObject:nil];
		hasParsed = [parserTimeoutLock lockWhenCondition:1 beforeDate:timeoutDate];
		if (hasParsed) {
			[parserTimeoutLock unlock];
		}
		
		if(hasParsed) {
			ACLog(@" - Parse complete, %d entries in archive.", [entries count]);
		} else {
			ACLog(@" - Parser timed out.");
		}
		
		return hasParsed;
	}
	return YES;
}

- (BOOL)closeParser {
	BOOL busy = NO;
	NSArray *allEntries = [entries allValues];
	for (ACArchiveEntry *entry in allEntries) {
		if (entry.handlePresent) {
			busy = YES;
			break;
		}
	}
	
	if (!busy) {
		ACLog(@"Closing archive parser for %@", path);
		[[parser handle] close];
		[parser release];
		parser = nil;
	}
	
	return !busy;
}


#pragma mark -
#pragma mark Custom property getters

- (XADArchiveParser *)parser {
	if (!parser) {
		@try {
			ACLog(@"Creating archive parser for %@", path);
			parser = [[XADArchiveParser archiveParserForPath:path] retain];
			[parser setDelegate:self];
		}
		@catch (NSException * e) {
			NSLog(@" - Could not create archive parser for %@", path);
			NSLog(@" - Exception: %@, Reason: %@", [e name], [e reason]);
		}
	}
	return parser;
}


#pragma mark -
#pragma mark Private methods

- (void)startParser {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[parserTimeoutLock lock];
	@try {
		[self.parser parse];
	}
	@catch (NSException *e) {
		NSLog(@" - Could not parse archive %@", path);
		NSLog(@" - Exception: %@, Reason: %@", [e name], [e reason]);
	}	
	if (![parserTimeoutLock tryLock]) {
		[parserTimeoutLock unlockWithCondition:1];
	}
	[pool release];
}


#pragma mark -
#pragma mark XADArchiveParser delegates

-(void)archiveParser:(XADArchiveParser *)theParser foundEntryWithDictionary:(NSDictionary *)dict {
	NSString *filename = [[dict objectForKey:XADFileNameKey] string];
	
	if (![entries objectForKey:filename]) {
		ACArchiveEntry *entry = [[ACArchiveEntry alloc] initWithFilename:filename];
		entry.parserDictionary = dict;
		entry.archive = self;
		
		[parserLock lock];
		[entries setObject:entry forKey:filename];
		[parserLock unlock];
		[entry release];
	}
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)theParser {
	return NO;
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)theParser {
	// TODO: Prompt for password?
}

@end
