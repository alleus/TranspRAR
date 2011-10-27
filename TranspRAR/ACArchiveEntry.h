//
//  ACArchiveEntry.h
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright 2010 Appcorn AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XADMaster/XADArchiveParser.h>


@class ACArchive;

@interface ACArchiveEntry : NSObject {
	NSString			*filename;
	NSMutableDictionary	*attributes;
	NSDictionary		*parserDictionary;
	XADHandle			*handle;

	ACArchive			*archive;
}

- (id)initWithFilename:(NSString *)aString;

@property (retain) NSString *filename;
@property (readonly) NSMutableDictionary *attributes;
@property (retain) NSDictionary *parserDictionary;
@property (retain) XADHandle *handle;
@property (assign) ACArchive *archive;
@property (readonly) BOOL handlePresent;

- (void)closeHandle;

@end
