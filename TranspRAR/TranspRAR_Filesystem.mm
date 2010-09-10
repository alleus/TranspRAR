//
//  TranspRAR_Filesystem.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-06.
//  Copyright 2010 Appcorn AB. All rights reserved.
//
#import <sys/xattr.h>
#import <sys/stat.h>
#import "TranspRAR_Filesystem.h"
#import <MacFUSE/MacFUSE.h>
#import <XADMaster/XADArchive.h>
#import <XADMaster/XADRegex.h>


// Category on NSError to  simplify creating an NSError based on posix errno.
@interface NSError (POSIX)
+ (NSError *)errorWithPOSIXCode:(int)code;
@end
@implementation NSError (POSIX)
+ (NSError *)errorWithPOSIXCode:(int) code {
  return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
}
@end

// NOTE: It is fine to remove the below sections that are marked as 'Optional'.

// The core set of file system operations. This class will serve as the delegate
// for GMUserFileSystemFilesystem. For more details, see the section on 
// GMUserFileSystemOperations found in the documentation at:
// http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html
@implementation TranspRAR_Filesystem

- (id)init {
	if ((self = [super init])) {
		paths = [[NSMutableDictionary alloc] init];
		fileManager = [[NSFileManager alloc] init];
		rootPath = @"";
	}
	return self;
}

- (void)dealloc {
	[paths release];
	paths = nil;
	[fileManager release];
	fileManager = nil;
	
	[super dealloc];
}


#pragma mark Directory Contents

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:error];
	
	NSMutableArray *returnArray = [NSMutableArray array];
	
	for (NSString *filename in contents) {
		BOOL ignoreFile = NO;
		BOOL isArchive = NO;
		
		if ([filename matchedByPattern:@"^.*\\.rar$" options:REG_ICASE]) {
			if ([filename matchedByPattern:@"^.*\\.part(([0-9]{1,3}))\\.rar$" options:REG_ICASE]) {
				if ([filename matchedByPattern:@"^.*\\.part(1|01|001)\\.rar$" options:REG_ICASE]) {
					isArchive = YES;
				} else {
					ignoreFile = YES;
				}
			} else {
				isArchive = YES;
			}
		} else if ([filename matchedByPattern:@"^.*\\.r[0-9]{2}$" options:REG_ICASE]) {
			ignoreFile = YES;
		} else if ([filename isEqualToString:@"TranspRAR"] && [path isEqualToString:@"/Volumes"]) {
			ignoreFile = YES;
		}
		
		if (isArchive) {
			NSString *archiveName = [NSString stringWithFormat:@"%@/%@", path, filename];
			
			// See if we have scanned the path before
			ACPath *pathObject = [paths objectForKey:path];
			// Prepare variable
			ACArchive *archive = nil;
			
			if (pathObject) {
				// Previous path object found, attempt to get archive
				archive = [pathObject archiveWithFilename:filename];
			} else {
				// Create new path object
				pathObject = [[ACPath alloc] init];
				[paths setObject:pathObject forKey:path];
				[pathObject release];
			}
			
			// See if we have scanned the archive before
			if (!archive) {
				// No previous scan found, create a new object
				archive = [[ACArchive alloc] init];
				[pathObject addArchive:archive withFilename:filename];
				[archive release];
				
				ACLog(@"creating parser for %@", archiveName);
				// Create a parser and start parsing the contents of the archive
				XADArchiveParser *parser = [XADArchiveParser archiveParserForPath:archiveName];
				[parser setDelegate:archive];
				[parser parse];
			}
			
			// Add all files contained in the archive to the return array
			[returnArray addObjectsFromArray:[archive entryFilenames]];
		} else if (!ignoreFile) {
			[returnArray addObject:filename];
		}
	}
	
	return returnArray;
}

#pragma mark Getting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path
                                userData:(id)userData
                                   error:(NSError **)error {
	ACPath *pathObject = [paths objectForKey:[path stringByDeletingLastPathComponent]];
	ACArchiveEntry *entry = [pathObject entryWithFilename:[path lastPathComponent]];
	
	if (entry) {
		return entry.attributes;
	} else {
		return [fileManager attributesOfItemAtPath:path error:error];
	}
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error {
	ACLog(@"attributesOfFileSystemForPath %@", path);
	return [NSDictionary dictionary];  // Default file system attributes.
}

#pragma mark File Contents

- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
	ACPath *pathObject = [paths objectForKey:[path stringByDeletingLastPathComponent]];
	ACArchiveEntry *entry = [pathObject entryWithFilename:[path lastPathComponent]];
	
	if (entry) {
		*userData = entry;
		entry.handle = [entry.parser handleForEntryWithDictionary:entry.parserDictionary wantChecksum:NO];
		
		if (entry.handle != nil) {
			return YES;
		} else {
			*error = [NSError errorWithPOSIXCode:ENOENT];
			return NO;
		}
	} else {
		*userData = [NSFileHandle fileHandleForReadingAtPath:path];
		if (userData) {
			return YES;
		} else {
			*error = [NSError errorWithPOSIXCode:ENOENT];
			return NO;
		}
	}
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData {
	ACLogFunction();
	ACLogObject(path);
	if ([userData isKindOfClass:[ACArchiveEntry class]]) {
		ACArchiveEntry *entry = userData;
		XADHandle *handle = entry.handle;
		[handle close];
		entry.handle = nil;
	} else {
		[userData closeFile];
	}
}

- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error {
	ACLog(@"offset = %lld size = %zu path = %@", offset, size, path);
	if ([userData isKindOfClass:[ACArchiveEntry class]]) {
		ACArchiveEntry *entry = userData;
		XADHandle *handle = entry.handle;
		[handle seekToFileOffset:offset];
		return [handle readAtMost:size toBuffer:buffer];
	} else {
		NSFileHandle *fileHandle = userData;
		[fileHandle seekToFileOffset:offset];
		NSData *readBytes = [fileHandle readDataOfLength:size];
		[readBytes getBytes:buffer];
		
		return [readBytes length];
	}
}


@end
