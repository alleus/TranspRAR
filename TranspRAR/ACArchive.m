//
//  ACArchive.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import "ACArchive.h"
#import <XADMaster/XADArchiveParser.h>

#define kCloseTimerInterval			1.0


@interface ACArchive ()

- (void)startParser;

- (void)startCloseTimer;

- (void)forceCloseParser:(NSTimer *)timer;

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
	}
	return self;
}

- (void)dealloc {
	[path release];
	path = nil;
	
	[entries release];
	entries = nil;
	[parser release];
	parser = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Custom methods

- (ACArchiveEntry *)entryWithFilename:(NSString *)filename {
	ACArchiveEntry *returnEntry = [entries objectForKey:filename];
	return returnEntry;
}

- (NSArray *)entryFilenames {
	NSArray *returnArray = [entries allKeys];
	return returnArray;
}

- (BOOL)parse {
	
	@synchronized(self) {
		if (!hasParsed) {
			
			// Create parser if not exising
			if (!parser) {
				@try {
					ACLog(@"Creating archive parser for %@", [path lastPathComponent]);
					parser = [[XADArchiveParser archiveParserForPath:path] retain];
					[parser setDelegate:self];
				}
				@catch (NSException * e) {
					NSLog(@" - Could not create archive parser for %@", [path lastPathComponent]);
					NSLog(@" - Exception: %@, Reason: %@", [e name], [e reason]);
				}
			}
			
			
			ACLog(@" - Parsing: %@", [path lastPathComponent]);
			
			
			
			
		
			[self startParser];
			hasParsed = YES;
			
			if(hasParsed) {
				ACLog(@" - Parsing %@ complete, %d entries in archive.", [path lastPathComponent], [entries count]);
			} else {
				ACLog(@" - Parsing %@ failed.", [path lastPathComponent]);
			}
			
			
			//[parser release];
			//parser = nil;
		}
		
		/*
		[[parser handle] close];
		[parser release];
		parser = nil;
		 */
	}
	
	
	return hasParsed;
}

- (BOOL)closeParser {
	
	BOOL busy = NO;
	/*
	NSArray *allEntries = [entries allValues];
	for (ACArchiveEntry *entry in allEntries) {
		if (entry.handlePresent) {
			busy = YES;
			break;
		}
	}
	 */
	
	if (!busy) {
		//[self performSelectorOnMainThread:@selector(startCloseTimer) withObject:nil waitUntilDone:YES];
		[self forceCloseParser:nil];
	}
	
	return !busy;
}

- (void)startCloseTimer {
	return;
	ACLog(@"Scheduling closing of archive parser in %f seconds for %@", kCloseTimerInterval, [path lastPathComponent]);
	[closeTimer invalidate];
	[closeTimer release];
	closeTimer = [[NSTimer scheduledTimerWithTimeInterval:kCloseTimerInterval target:self selector:@selector(forceCloseParser:) userInfo:nil repeats:NO] retain];
}

- (void)forceCloseParser:(NSTimer *)timer {
	ACLog(@"Closing archive parser for %@", [path lastPathComponent]);
	
	/*
	[[parser handle] close];
	[parser release];
	parser = nil;
	 */
	/*
	hasParsed = NO;
	[closeTimer release];
	closeTimer = nil;
	 */
}


#pragma mark -
#pragma mark Parser

- (XADArchiveParser *)parser {
	return parser;
}


#pragma mark -
#pragma mark Private methods

- (void)startParser {
	NSLog(@"startParser: begin");
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	@try {
		NSLog(@"1");
		[parser parse];
		//[parser performSelectorOnMainThread:@selector(parse) withObject:nil waitUntilDone:YES];
		NSLog(@"2");
	}
	@catch (NSException *e) {
		NSLog(@" - Could not parse archive %@", [path lastPathComponent]);
		NSLog(@" - Exception: %@, Reason: %@", [e name], [e reason]);
		//hasParsed = NO;
	}	
	[pool release];
	NSLog(@"startParser: end");
}


#pragma mark -
#pragma mark XADArchiveParser delegates

-(void)archiveParser:(XADArchiveParser *)theParser foundEntryWithDictionary:(NSDictionary *)dict {
	NSString *filename = [[dict objectForKey:XADFileNameKey] string];
	
	NSLog(@"found entry with dictionary: %@", dict);
	
	if (![entries objectForKey:filename]) {
		ACArchiveEntry *entry = [[ACArchiveEntry alloc] initWithFilename:filename];
		entry.parserDictionary = dict;
		entry.archive = self;
	
		[entries setObject:entry forKey:filename];

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
