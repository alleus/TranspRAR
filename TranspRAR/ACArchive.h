//
//  ACArchive.h
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ACArchiveEntry.h"

enum {PARSE_INCOMPLETE, PARSE_COMPLETE};

@interface ACArchive : NSObject {
	NSMutableDictionary		*entries;			// ACArchiveEntry objects, where the key is the filename of the entry.
	NSString				*path;				// The complete path of the archive.
	XADArchiveParser		*parser;			// The parser used to list and unpack archives.
	BOOL					hasParsed;			// Flag indicating if the archive has been successfully parsed before.
	NSLock					*parserLock;		// Thread lock used when parsing the archive in a separate thread.
	NSConditionLock			*parserTimeoutLock;	// Conditional lock used to provide a timeout for parsing.
	NSTimer					*closeTimer;
}

@property (retain) NSString *path;
@property (readonly) XADArchiveParser *parser;	// Created on demand.

/* Initiates the object and sets the path. */
- (id)initWithPath:(NSString *)aString;

/* Looks up the requested parsed entry and returns it. If no entry was found, nil will be returned. */
- (ACArchiveEntry *)entryWithFilename:(NSString *)filename;

/* Returns array of strings represening the filenames for all parsed entries in the archive. */
- (NSArray *)entryFilenames;

/* Initiates the parsing of the archive. This involves detaching a separate thread. If the parsing takes longer than a specified timeout this method will return NO. In all other cases (even if the parser failed to read the archive), YES will be returned. If the archive has already been parsed, this method returns YES and does nothing. */
- (BOOL)parse;

/* Attempts to close the parser by first making sure that no entries are currenty having any open handlers. If the parser was closed, this method returns YES. */
- (BOOL)closeParser;

@end
