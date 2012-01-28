//
//  TranspRAR_Controller.h
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-06.
//  Copyright 2010 Appcorn AB. All rights reserved.
//
#import <Cocoa/Cocoa.h>

@class GMUserFileSystem;
@class TranspRAR_Filesystem;

@interface TranspRAR_Controller : NSObject {
	GMUserFileSystem *fs_;
	TranspRAR_Filesystem *fs_delegate_;
	NSConnection *connection;
}

+ (BOOL)debugLogging;
- (void)startServer;
- (void)showMountError:(NSError *)error;

@end
