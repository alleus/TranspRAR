//
//  TranspRAR_Controller.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-06.
//  Copyright 2010 Appcorn AB. All rights reserved.
//
#import "TranspRAR_Controller.h"
#import "TranspRAR_Filesystem.h"
#import <OSXFUSE/OSXFUSE.h>


#define kRootPath			@"RootPath"
#define kDebugLogging		@"DebugLogging"
#define kColorLabels		@"ColorLabels"
#define kPersistentDomain	@"com.alleus.TranspRAR.pref"


@implementation TranspRAR_Controller

static BOOL debugLogging;
static BOOL colorLabels;

- (void)mountFailed:(NSNotification *)notification {
	NSDictionary* userInfo = [notification userInfo];
	NSError* error = [userInfo objectForKey:kGMUserFileSystemErrorKey];
	NSLog(@"kGMUserFileSystem Error: %@, userInfo=%@", error, [error userInfo]);
	[self performSelectorOnMainThread:@selector(showMountError:) withObject:error waitUntilDone:YES];
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)didMount:(NSNotification *)notification {
	NSDictionary* userInfo = [notification userInfo];
	NSString* mountPath = [userInfo objectForKey:kGMUserFileSystemMountPathKey];
	NSString* parentPath = [mountPath stringByDeletingLastPathComponent];
	[[NSWorkspace sharedWorkspace] selectFile:mountPath
					 inFileViewerRootedAtPath:parentPath];
}

- (void)didUnmount:(NSNotification*)notification {
	[[NSApplication sharedApplication] terminate:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(mountFailed:)
				   name:kGMUserFileSystemMountFailed object:nil];
	[center addObserver:self selector:@selector(didMount:)
				   name:kGMUserFileSystemDidMount object:nil];
	[center addObserver:self selector:@selector(didUnmount:)
				   name:kGMUserFileSystemDidUnmount object:nil];
	
	NSString* mountPath = @"/Volumes/TranspRAR";
	fs_delegate_ = [[TranspRAR_Filesystem alloc] init];
	/*NSString *rootPath = [[[NSUserDefaults standardUserDefaults] persistentDomainForName:kPersistentDomain] objectForKey:kRootPath];
	if (rootPath) {
		fs_delegate_.rootPath = rootPath;
	}*/
	fs_delegate_.rootPath = @"/";
	fs_ = [[GMUserFileSystem alloc] initWithDelegate:fs_delegate_ isThreadSafe:NO];
	debugLogging = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:kPersistentDomain] objectForKey:kDebugLogging] boolValue];
	colorLabels = [[[[NSUserDefaults standardUserDefaults] persistentDomainForName:kPersistentDomain] objectForKey:kColorLabels] boolValue];
	
	NSMutableArray* options = [NSMutableArray array];
	NSString* volArg = [NSString stringWithFormat:@"volicon=%@", [[NSBundle mainBundle] pathForResource:@"TranspRAR" ofType:@"icns"]];
	[options addObject:volArg];
	[options addObject:@"volname=TranspRAR"];
	[options addObject:@"rdonly"];
	[fs_ mountAtPath:mountPath withOptions:options];
	
	[self startServer];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[fs_ unmount];
	[fs_ release];
	[fs_delegate_ release];
	return NSTerminateNow;
}

+ (BOOL)debugLogging {
	return debugLogging;
}

+ (BOOL)colorLabels {
	return colorLabels;
}

- (void)startServer {
	connection = [[NSConnection alloc] init];
	[connection setRootObject:self];
	[connection registerName:@"TranspRAR"];
}

- (void)showMountError:(NSError *)error {
	NSRunAlertPanel(@"Mount Failed", [error localizedDescription], nil, nil, nil);
}

- (oneway)terminate {
	[[NSApplication sharedApplication] terminate:nil];
	return nil;
}

@end
