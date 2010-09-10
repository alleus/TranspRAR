//
//  TranspRAR_Filesystem.h
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-06.
//  Copyright 2010 Appcorn AB. All rights reserved.
//
// Filesystem operations.
//

#import <Foundation/Foundation.h>
#import "ACPath.h"

// The core set of file system operations. This class will serve as the delegate
// for GMUserFileSystemFilesystem. For more details, see the section on 
// GMUserFileSystemOperations found in the documentation at:
// http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html
@interface TranspRAR_Filesystem : NSObject  {
	NSMutableDictionary		*paths;
	
	NSString				*rootPath;
}

@end
