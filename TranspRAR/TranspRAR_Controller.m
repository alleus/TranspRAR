//
//  TranspRAR_Controller.m
//  TranspRAR
//
//  Created by Martin Alléus on 2010-09-06.
//  Copyright 2010 Appcorn AB. All rights reserved.
//
#import "TranspRAR_Controller.h"
#import "TranspRAR_Filesystem.h"
#import <MacFUSE/MacFUSE.h>

@implementation TranspRAR_Controller

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
  fs_ = [[GMUserFileSystem alloc] initWithDelegate:fs_delegate_ isThreadSafe:NO];

  NSMutableArray* options = [NSMutableArray array];
  NSString* volArg = 
    [NSString stringWithFormat:@"volicon=%@", 
     [[NSBundle mainBundle] pathForResource:@"TranspRAR" ofType:@"icns"]];
  [options addObject:volArg];
  [options addObject:@"volname=TranspRAR"];
  [options addObject:@"rdonly"];
  [fs_ mountAtPath:mountPath withOptions:options];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [fs_ unmount];
  [fs_ release];
  [fs_delegate_ release];
  return NSTerminateNow;
}

- (void)showMountError:(NSError *)error {
	NSRunAlertPanel(@"Mount Failed", [error localizedDescription], nil, nil, nil);
}

@end
