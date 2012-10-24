// Created by Martin Alléus.
// Copyright 2010 Appcorn AB. All rights reserved.
// Copyright 2012 Ben Trask. All rights reserved.

@class TRNode;

@interface TRFilesystem : NSObject
{
	@private
	NSString *_rootPath;
	NSMutableDictionary *_nodeByArchivePath;
}

@property(copy, nonatomic) NSString *rootPath;

- (TRNode *)nodeForArchivePath:(NSString *const)path;

@end
