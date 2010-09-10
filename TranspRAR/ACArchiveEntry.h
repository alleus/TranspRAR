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
	NSMutableDictionary	*attributes;
	NSDictionary		*parserDictionary;
	XADArchiveParser	*parser;
	XADHandle			*handle;
	
	ACArchive			*archive;
}

@property (readonly) NSMutableDictionary *attributes;
@property (retain) NSDictionary *parserDictionary;
@property (retain) XADArchiveParser *parser;
@property (retain) XADHandle *handle;
@property (assign) ACArchive *archive;

@end
