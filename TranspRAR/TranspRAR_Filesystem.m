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


@interface TranspRAR_Filesystem ()

- (ACArchiveEntry *)archiveEntryForPath:(NSString *)path;

@end


// The core set of file system operations. This class will serve as the delegate
// for GMUserFileSystemFilesystem. For more details, see the section on 
// GMUserFileSystemOperations found in the documentation at:
// http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html
@implementation TranspRAR_Filesystem

@synthesize rootPath;

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
	[rootPath release];
	rootPath = nil;
	
	[super dealloc];
}

- (ACArchiveEntry *)archiveEntryForPath:(NSString *)path {
	ACPath *pathObject = [paths objectForKey:[path stringByDeletingLastPathComponent]];
	
	if (!pathObject && ![fileManager fileExistsAtPath:path]) {
		if (![path matchedByPattern:@"(^.*\\.DS_Store$)|(^.*/Contents$)|(^.*/\\._.*$)" options:REG_BASIC]) {
			// We don't attempt to parse for the following files: /something/.DS_Store, /something/file.rar/Contents and /something/._file.rar
			ACLog(@"Could not locate %@, parsing parent folder", path);
			[self contentsOfDirectoryAtPath:[path stringByDeletingLastPathComponent] error:NULL];
			pathObject = [paths objectForKey:[path stringByDeletingLastPathComponent]];
		}
	}
	
	return [pathObject entryWithFilename:[path lastPathComponent]];
}


#pragma mark Directory Contents

- (NSArray *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	ACLog(@"Reading directory contents of %@", path);
	NSArray *contents = [fileManager contentsOfDirectoryAtPath:path error:&*error];
	
	if (contents == nil) {
		return nil;
	}
	
	NSMutableArray *returnArray = [[NSMutableArray alloc] init];
	
	for (NSString *filename in contents) {
		BOOL ignoreFile = NO;
		BOOL isArchive = NO;
		
		// "(\.part(1|01|001)\.rar$)|(^(?:(?!part\d{1,3}).)*\.rar$)"
		if ([filename matchedByPattern:@"(^.*\\.rar$)|(^.*\\.001$)|(^.*\\.zip$)" options:REG_ICASE]) {
			if ([filename matchedByPattern:@"^.*\\.part(([0-9]{1,3}))\\.rar$" options:REG_ICASE]) {
				// One of the parts of a splitted archive (*.part001.rar, *.part002.rar, etc...)
				if ([filename matchedByPattern:@"^.*\\.part(1|01|001)\\.rar$" options:REG_ICASE]) {
					// The first part of the archive (*.part001.rar)
					isArchive = YES;
				} else {
					// One of the other parts (*.part002.rar, *.part003.rar, etc...)
					ignoreFile = YES;
				}
			} else {
				// Regular *.rar-file
				isArchive = YES;
			}
		} else if ([filename matchedByPattern:@"^.*\\.r[0-9]{2}$" options:REG_ICASE]) {
			// Ignore all *.r00, *.r01, etc... files
			ignoreFile = YES;
		} else if ([filename isEqualToString:@"TranspRAR"] && [[path lastPathComponent] isEqualToString:@"Volumes"]) {
			// Ignore the */Volumes/TranspRAR folder to stop any nasty loops
			ignoreFile = YES;
		}
		
		if (isArchive) {
			// Archive! Start the procedure of reading the content
			NSString *archiveName = nil;
			if ([path isEqualToString:@"/"]) {
				archiveName = [NSString stringWithFormat:@"/%@", filename];
			} else {
				archiveName = [NSString stringWithFormat:@"%@/%@", path, filename];
			}
			
			// See if we have scanned archives in the directory before
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
				archive = [[ACArchive alloc] initWithPath:archiveName];
				[pathObject addArchive:archive withFilename:filename];
				[archive release];
				
				// Create a parser and start parsing the contents of the archive.
				// If the parser locks up, this will return after a specified timeout.
				[archive parse];
				// Attempt to close the parser (if there are any entry handlers, it won't close)
				[archive closeParser];
			}
			
			// Add all files contained in the archive (if any were added in the parsing) to the return array
			[returnArray addObjectsFromArray:[archive entryFilenames]];
		} else if (!ignoreFile) {
			[returnArray addObject:filename];
		}
	}
	
	return [returnArray autorelease];
}

#pragma mark Getting Attributes

- (NSDictionary *)attributesOfItemAtPath:(NSString *)path
                                userData:(id)userData
                                   error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	ACArchiveEntry *entry = [self archiveEntryForPath:path];
	
	
	if (entry) {
		return entry.attributes;
	} else {
		return [fileManager attributesOfItemAtPath:path error:error];
	}
}

- (NSDictionary *)attributesOfFileSystemForPath:(NSString *)path
                                          error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	NSDictionary *dictionary = [fileManager attributesOfFileSystemForPath:path error:error];
	if (dictionary) {
		NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithDictionary:dictionary];
		[attributes setObject:[NSNumber numberWithBool:YES] forKey:kGMUserFileSystemVolumeSupportsExtendedDatesKey];
		return attributes;
	}
	return nil;
}

- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	NSString *destinationPath = [fileManager destinationOfSymbolicLinkAtPath:path error:&*error];
	if (destinationPath) {
		return [NSString stringWithFormat:@"/Volumes/TranspRAR%@", destinationPath];
	}
	
	return nil;
}

#pragma mark File Contents

- (BOOL)openFileAtPath:(NSString *)path 
                  mode:(int)mode
              userData:(id *)userData
                 error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	ACArchiveEntry *entry = [self archiveEntryForPath:path];
	
	if (entry) {
		*userData = entry;
		
		if (entry.handle != nil) {
			return YES;
		} else {
			*error = [NSError errorWithPOSIXCode:ENOENT];
			return NO;
		}
	} else {
		int fd = open([path UTF8String], mode);
		
		if (fd < 0) {
			*error = [NSError errorWithPOSIXCode:errno];
			return NO;
		}
		
		*userData = [NSNumber numberWithLong:fd];
		return YES;
	}
}

- (void)releaseFileAtPath:(NSString *)path userData:(id)userData {
	path = [rootPath stringByAppendingString:path];
	if ([userData isKindOfClass:[ACArchiveEntry class]]) {
		ACArchiveEntry *entry = userData;
		[entry closeHandle];
		[entry.archive closeParser];
	} else {
		NSNumber *num = (NSNumber *)userData;
		int fd = [num longValue];
		close(fd);
	}
}

- (int)readFileAtPath:(NSString *)path 
             userData:(id)userData
               buffer:(char *)buffer 
                 size:(size_t)size 
               offset:(off_t)offset
                error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	if ([userData isKindOfClass:[ACArchiveEntry class]]) {
		ACArchiveEntry *entry = userData;
		XADHandle *handle = entry.handle;
		[handle seekToFileOffset:offset];
		return [handle readAtMost:size toBuffer:buffer];
	} else {
		NSNumber *num = (NSNumber *)userData;
		int fd = [num longValue];
		int ret = pread(fd, buffer, size, offset);
		if (ret < 0) {
			*error = [NSError errorWithPOSIXCode:errno];
			return -1;
		}
		return ret;
	}
}

#pragma mark Extended Attributes

/*- (NSArray *)extendedAttributesOfItemAtPath:(NSString *)path error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	ACArchiveEntry *entry = [self archiveEntryForPath:path];
	
	if (entry) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	} else {
		ssize_t size = listxattr([path UTF8String], nil, 0, 0);
		if (size < 0) {
			*error = [NSError errorWithPOSIXCode:errno];
			return nil;
		}
		NSMutableData *data = [NSMutableData dataWithLength:size];
		size = listxattr([path UTF8String], (char *)[data mutableBytes], [data length], 0);
		if (size < 0) {
			*error = [NSError errorWithPOSIXCode:errno];
			return nil;
		}
		NSMutableArray *contents = [NSMutableArray array];
		char *ptr = (char *)[data bytes];
		while (ptr < ((char *)[data bytes] + size)) {
			NSString* s = [NSString stringWithUTF8String:ptr];
			[contents addObject:s];
			ptr += ([s length] + 1);
		}
		return contents;
	}
}

- (NSData *)valueOfExtendedAttribute:(NSString *)name 
                        ofItemAtPath:(NSString *)path
                            position:(off_t)position
                               error:(NSError **)error {
	path = [rootPath stringByAppendingString:path];
	ACArchiveEntry *entry = [self archiveEntryForPath:path];
	
	if (entry) {
		*error = [NSError errorWithPOSIXCode:errno];
		return nil;
	} else {
		ssize_t size = getxattr([path UTF8String], [name UTF8String], nil, 0, position, 0);
		if (size < 0) {
			*error = [NSError errorWithPOSIXCode:errno];
			return nil;
		}
		NSMutableData *data = [NSMutableData dataWithLength:size];
		size = getxattr([path UTF8String], [name UTF8String], [data mutableBytes], [data length], position, 0);
		if ( size < 0 ) {
			*error = [NSError errorWithPOSIXCode:errno];
			return nil;
		}  
		return data;
	}
}*/

- (void)setRootPath:(NSString *)string {
	if (rootPath != string) {
		if ([string isEqualToString:@"/"]) {
			string = @"";
		}
		[rootPath release];
		rootPath = [string retain];
	}
}


@end
