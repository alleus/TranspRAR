// Copyright 2012 Ben Trask. All rights reserved.
#import <XADMaster/XADArchiveParser.h>

static BOOL TRIsArchivePath(NSString *const path) // TODO: Put this somewhere.
{
	static NSSet *exts = nil;
	if(!exts) exts = [[NSSet setWithArray:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"TRSupportedExtensions"]] retain];
	return [exts containsObject:[[path pathExtension] lowercaseString]];
}

@interface TRNode : NSObject
{
	@private
	NSMutableDictionary *_nodeByName;
	NSDictionary *_info;
	XADArchiveParser *_parser;
}

- (TRNode *)nodeForSubpath:(NSString *const)subpath;
- (TRNode *)nodeForSubpath:(NSString *const)subpath createIfNeeded:(BOOL const)flag;
- (TRNode *)nodeForSubpathComponents:(NSArray *const)components createIfNeeded:(BOOL const)flag;

- (void)setNode:(TRNode *const)node forName:(NSString *const)name;

- (BOOL)hasChildren;
- (NSArray *)nodeNames;
- (NSArray *)nodes;

@property(retain, nonatomic) NSDictionary *info;
@property(retain, nonatomic) XADArchiveParser *parser;

@end

@interface TRNodeLoader : NSObject
{
	@private
	XADArchiveParser *_parser;
	TRNode *_node;
}

- (id)initWithParser:(XADArchiveParser *const)parser error:(XADError *const)error;
- (XADArchiveParser *)parser;
- (TRNode *)node;

@end
