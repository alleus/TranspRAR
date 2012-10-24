// Created by Martin Alléus.
// Copyright 2010 Appcorn AB. All rights reserved.
// Copyright 2012 Ben Trask. All rights reserved.
#import "TRFilesystem.h"
#import <sys/xattr.h>
#import <sys/stat.h>
#import <MacFUSE/MacFUSE.h>
#import <XADMaster/XADArchive.h>
#import <XADMaster/XADRegex.h>

#import "TRNode.h"

// MacFUSE documentation: http://macfuse.googlecode.com/svn/trunk/core/sdk-objc/Documentation/index.html

enum {
	kColorNone   = 0 << 1,
	kColorRed    = 6 << 1,
	kColorOrange = 7 << 1,
	kColorYellow = 5 << 1,
	kColorGreen  = 2 << 1,
	kColorBlue   = 4 << 1,
	kColorPurple = 3 << 1,
	kColorGray   = 1 << 1,
};

static NSError *TRErrorWithInt(int const code)
{
	return [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
}
static NSString *TRSubpathFromDirectory(NSString *const path, NSString *const directory)
{
	NSCParameterAssert([directory hasSuffix:@"/"]);
	NSCParameterAssert(![directory hasSuffix:@"//"]);
	if(![path hasPrefix:directory]) return nil;
	return [path substringFromIndex:[directory length]];
}
static BOOL TRGetArchiveAndSubpathForPath(NSString **const archivePath, NSString **const subpath, NSString *const path)
{
	if(archivePath) *archivePath = nil;
	if(subpath) *subpath = nil;
	if([[NSFileManager defaultManager] fileExistsAtPath:path]) return YES;
	NSString *p = path;
	for(;;) {
		p = [p stringByDeletingLastPathComponent];
		if([@"/" isEqualToString:p]) return NO;
		if(![[NSFileManager defaultManager] fileExistsAtPath:p]) continue;
		if(!TRIsArchivePath(p)) return NO;
		if(archivePath) *archivePath = p;
		if(subpath) *subpath = TRSubpathFromDirectory(path, [p stringByAppendingString:@"/"]);
		return YES;
	}
	return NO;
}

@implementation TRFilesystem

- (NSString *)rootPath
{
	return [[_rootPath retain] autorelease];
}
- (void)setRootPath:(NSString *const)rootPath
{
	if([@"/" isEqualToString:rootPath]) return [self setRootPath:@""];
	if([_rootPath isEqualToString:rootPath]) return;
	[_rootPath release];
	_rootPath = [rootPath copy];
}

#pragma mark -

- (TRNode *)nodeForArchivePath:(NSString *const)path
{
	if(!path) return nil;
	TRNode *node = [_nodeByArchivePath objectForKey:path];
	if(node) return node;
	XADArchiveParser *const parser = [XADArchiveParser archiveParserForPath:path error:NULL];
	TRNodeLoader *const loader = [[[TRNodeLoader alloc] initWithParser:parser error:NULL] autorelease];
	node = [loader node];
	[_nodeByArchivePath setObject:node forKey:path];
	return node;
}

#pragma mark -NSObject(GMUserFileSystemOperations)

- (NSArray *)contentsOfDirectoryAtPath:(NSString *const)path error:(NSError **const)error
{
	if(error) *error = nil;
	NSString *const fullpath = [_rootPath stringByAppendingString:path];
	if([fullpath hasPrefix:@"/Volumes/TranspRAR/"]) return nil; // TODO: Dynamic mount points?
	NSString *archivePath = nil;
	NSString *subpath = nil;
	if(!TRGetArchiveAndSubpathForPath(&archivePath, &subpath, fullpath)) return nil;
	if(archivePath) {
		return [[[self nodeForArchivePath:archivePath] nodeForSubpath:subpath] nodeNames];
	} else if(TRIsArchivePath(fullpath)) {
		return [[self nodeForArchivePath:fullpath] nodeNames];
	} else {
		return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:fullpath error:error];
	}
}
- (NSDictionary *)attributesOfItemAtPath:(NSString *const)path userData:(id const)userData error:(NSError **const)error
{
	if(error) *error = nil;
	NSString *const fullpath = [_rootPath stringByAppendingString:path];
	BOOL const checkingForBundle = [@"Contents" isEqualToString:[fullpath lastPathComponent]];
	if(checkingForBundle) {
		BOOL const insideAnArchive = TRIsArchivePath([fullpath stringByDeletingLastPathComponent]);
		if(insideAnArchive) {
			NSDictionary *const tooExpensive = nil;
			return tooExpensive;
		}
	}
	NSString *archivePath = nil;
	NSString *subpath = nil;
	if(!TRGetArchiveAndSubpathForPath(&archivePath, &subpath, fullpath)) return nil;
	if(archivePath) {
		TRNode *const node = [[self nodeForArchivePath:archivePath] nodeForSubpath:subpath];
		NSDictionary *const info = [node info];
		if([[info objectForKey:XADIsDirectoryKey] boolValue] || [node hasChildren]) {
			return [NSDictionary dictionaryWithObjectsAndKeys:
				NSFileTypeDirectory, NSFileType,
				nil];
		} else {
			if(!info) return nil;
			return [NSDictionary dictionaryWithObjectsAndKeys:
				[info objectForKey:XADFileSizeKey], NSFileSize,
				[info objectForKey:XADLastModificationDateKey], NSFileModificationDate,
				[info objectForKey:XADCreationDateKey], NSFileCreationDate,
				NSFileTypeRegular, NSFileType,
				nil];
		}
	} else if(TRIsArchivePath(fullpath)) {
		return [NSDictionary dictionaryWithObjectsAndKeys:
			NSFileTypeDirectory, NSFileType,
			nil];
	} else {
		return [[NSFileManager defaultManager] attributesOfItemAtPath:fullpath error:error];
	}
}
- (NSDictionary *)attributesOfFileSystemForPath:(NSString *const)path error:(NSError **const)error
{
	NSString *const fullpath = [_rootPath stringByAppendingString:path];
	NSMutableDictionary *const attrs = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:fullpath error:error] mutableCopy] autorelease];
	[attrs setObject:[NSNumber numberWithBool:YES] forKey:kGMUserFileSystemVolumeSupportsExtendedDatesKey];
	return attrs;
}
- (NSString *)destinationOfSymbolicLinkAtPath:(NSString *const)path error:(NSError **const)error
{
	if(error) *error = nil;
	NSString *const fullpath = [_rootPath stringByAppendingString:path];
	NSString *const target = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:fullpath error:error];
	return target ? [@"/Volumes/TranspRAR" stringByAppendingString:target] : nil;
}

- (BOOL)openFileAtPath:(NSString *const)path mode:(int const)mode userData:(id *const)userInfo error:(NSError **const)error
{
	if(error) *error = nil;
	if(O_RDONLY != mode) return NO; // TODO: Return error.
	NSString *const fullpath = [_rootPath stringByAppendingString:path];
	NSString *archivePath = nil;
	NSString *subpath = nil;
	if(!TRGetArchiveAndSubpathForPath(&archivePath, &subpath, fullpath)) return NO;
	if(archivePath) {
		TRNode *const node = [[self nodeForArchivePath:archivePath] nodeForSubpath:subpath];
		*userInfo = node;
		return !!node; // TODO: Return error.
	} else {
		int const fd = open([fullpath UTF8String], mode);
		if(fd < 0) {
			*error = TRErrorWithInt(errno);
			return NO;
		}
		*userInfo = [NSNumber numberWithInt:fd];
		return YES;
	}
}
- (void)releaseFileAtPath:(NSString *const)path userData:(id const)userInfo
{
	if([userInfo isKindOfClass:[NSNumber class]]) {
		(void)close([userInfo intValue]);
	} else {
		// We open and close sub-handles for each read, so we don't need to do anything here.
		// However, we should add archive/node unloading at some point.
	}
}
- (int)readFileAtPath:(NSString *const)path userData:(id const)userInfo buffer:(char *const)buffer size:(size_t const)size offset:(off_t const)offset error:(NSError **const)error
{
	if([userInfo isKindOfClass:[NSNumber class]]) {
		int const ret = pread([userInfo intValue], buffer, size, offset);
		if(ret < 0) {
			*error = TRErrorWithInt(errno);
			return -1;
		}
		return ret;
	} else {
		if(error) *error = nil;
		TRNode *const node = userInfo;
		CSHandle *const handle = [[node parser] handleForEntryWithDictionary:[node info] wantChecksum:NO];
		[handle seekToFileOffset:offset];
		int const length = [handle readAtMost:size toBuffer:buffer];
		[handle close];
		return length;
	}
}

#pragma mark -NSObject(GMUserFileSystemResourceForks)

- (NSDictionary *)finderAttributesAtPath:(NSString *const)path error:(NSError **const)error
{
	if(error) *error = nil;
	NSString *archivePath = nil;
	NSString *subpath = nil;
	NSString *const fullpath = [_rootPath stringByAppendingString:path];
	if(!TRGetArchiveAndSubpathForPath(&archivePath, &subpath, fullpath)) return nil;

	UInt16 flags = kNilOptions;
	if(archivePath) {
		if([TRController colorLabels]) flags |= kColorOrange;
		if([[subpath lastPathComponent] hasPrefix:@"."]) flags |= kIsInvisible;
	} else {
		if([TRController colorLabels] && TRIsArchivePath(fullpath)) flags |= kColorOrange;
		LSItemInfoRecord info = {};
		if(LSCopyItemInfoForURL((CFURLRef)[NSURL fileURLWithPath:fullpath], kLSRequestBasicFlagsOnly, &info) == noErr && info.flags & kLSItemInfoIsInvisible) flags |= kIsInvisible;
		else {
			static NSSet *ignoredPaths = nil;
			if(!ignoredPaths) ignoredPaths = [[NSSet setWithObjects:@"/dev", @"/net", @"/etc", @"/home", @"/tmp", @"/var", @"/mach_kernel.ctfsys", @"/mach.sym", nil] retain];
			if([ignoredPaths containsObject:fullpath]) flags |= kIsInvisible;
		}
	}
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedShort:flags], kGMUserFileSystemFinderFlagsKey,
		nil];
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

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		_rootPath = @"";
		_nodeByArchivePath = [[NSMutableDictionary alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_rootPath release];
	[_nodeByArchivePath release];
	[super dealloc];
}

@end
