// Created by Martin Alléus.
// Copyright 2010 Appcorn AB. All rights reserved.
@class GMUserFileSystem;
@class TRFilesystem;

@interface TRController : NSObject
{
	@private
	GMUserFileSystem *fs_;
	TRFilesystem *fs_delegate_;
	NSConnection *connection;
}

+ (BOOL)debugLogging;
+ (BOOL)colorLabels;
- (void)startServer;
- (void)showMountError:(NSError *)error;

@end
