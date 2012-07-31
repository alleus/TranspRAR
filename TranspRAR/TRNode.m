// Copyright 2012 Ben Trask. All rights reserved.
#import "TRNode.h"
#import <XADMaster/CSMemoryHandle.h>

@implementation TRNode

#pragma mark -TRNode

- (TRNode *)nodeForSubpath:(NSString *const)subpath
{
	return [self nodeForSubpath:subpath createIfNeeded:NO];
}
- (TRNode *)nodeForSubpath:(NSString *const)subpath createIfNeeded:(BOOL const)flag
{
	return [self nodeForSubpathComponents:[subpath componentsSeparatedByString:@"/"] createIfNeeded:flag];
}
- (TRNode *)nodeForSubpathComponents:(NSArray *const)components createIfNeeded:(BOOL const)flag
{
	NSUInteger const len = [components count];
	if(!len) return self;
	NSString *const component = [components objectAtIndex:0];
	TRNode *node = [_nodeByName objectForKey:component];
	if(!node) {
		if(!flag) return nil;
		node = [[(TRNode *)[TRNode alloc] init] autorelease];
		[node setParser:_parser];
		[_nodeByName setObject:node forKey:component];
	}
	return [node nodeForSubpathComponents:[components subarrayWithRange:NSMakeRange(1, len - 1)] createIfNeeded:flag];
}

#pragma mark -

- (void)setNode:(TRNode *const)node forName:(NSString *const)name
{
	[_nodeByName setObject:node forKey:name];
}

#pragma mark -

- (BOOL)hasChildren
{
	return [[_nodeByName allKeys] count] > 0;
}
- (NSArray *)nodeNames
{
	return [_nodeByName allKeys];
}
- (NSArray *)nodes
{
	return [_nodeByName allValues];
}

#pragma mark -

@synthesize info = _info;
@synthesize parser = _parser;

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		_nodeByName = [[NSMutableDictionary alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_nodeByName release];
	[_info release];
	[_parser release];
	[super dealloc];
}

@end

@implementation TRNodeLoader

#pragma mark -TRNodeLoader

- (id)initWithParser:(XADArchiveParser *const)parser error:(XADError *const)error
{
	NSParameterAssert(parser);
	if((self = [super init])) {
		_parser = [parser retain];
		[_parser setDelegate:self];

		_node = [[TRNode alloc] init];
		[_node setParser:_parser];
		XADError const err = [parser parseWithoutExceptions];
		if(error) *error = err;

		NSArray *const subNodes = [_node nodes];
		if(1 == [subNodes count]) {
			TRNode *const subNode = [subNodes objectAtIndex:0];
			BOOL const isIntermediateFolder = [subNode hasChildren];
			if(isIntermediateFolder) {
				BOOL const isPackage = !![subNode nodeForSubpath:@"Contents"];
				if(!isPackage) {
					[_node autorelease];
					_node = [subNode retain];
				}
			}
		}
	}
	return self;
}
- (XADArchiveParser *)parser
{
	return [[_parser retain] autorelease];
}
- (TRNode *)node
{
	return [[_node retain] autorelease];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_parser release];
	[_node release];
	[super dealloc];
}

#pragma mark -NSObject(XADArchiveParserDelegate)

- (void)archiveParser:(XADArchiveParser *const)parser foundEntryWithDictionary:(NSDictionary *const)dict
{
	NSParameterAssert(parser == _parser);
	NSArray *const components = [(XADPath *)[dict objectForKey:XADFileNameKey] pathComponents];
	NSUInteger const count = [components count];
	XADArchiveParser *subParser = nil;
	if(count) {
		if([[dict objectForKey:XADIsArchiveKey] boolValue]) {
			subParser = [XADArchiveParser archiveParserForEntryWithDictionary:dict archiveParser:parser wantChecksum:NO error:NULL];
		} else if(TRIsArchivePath([components lastObject])) {
			CSHandle *const handle = [_parser handleForEntryWithDictionary:dict wantChecksum:NO error:NULL];
			// if(handle) subParser = [XADArchiveParser archiveParserForHandle:handle name:[components lastObject] error:NULL];
			// Doesn't work, we can parse it fine but we crash when trying to get a sub-handle to read data from it.
			// Incidentally, this is the same error we get when we try to use +archiveParserForEntryWithDictionary:...
			NSData *const data = [handle remainingFileContents];
			if(data) subParser = [XADArchiveParser archiveParserForHandle:[CSMemoryHandle memoryHandleForReadingData:data] name:[components lastObject] error:NULL];
		}
	}
	if(subParser) {
		TRNodeLoader *const loader = [[[TRNodeLoader alloc] initWithParser:subParser error:NULL] autorelease];
		TRNode *const node = [loader node];
		TRNode *const parent = [_node nodeForSubpathComponents:[components subarrayWithRange:NSMakeRange(0, count - 1)] createIfNeeded:YES];
		[parent setNode:node forName:[components lastObject]];
		[node setInfo:dict];
	} else {
		[[_node nodeForSubpathComponents:components createIfNeeded:YES] setInfo:dict];
	}
}

@end
