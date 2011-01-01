//
//  TranspRARPrefPref.m
//  TranspRARPref
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright (c) 2010 Appcorn AB. All rights reserved.
//

#import "TranspRARPref.h"

#define kRootPath			@"RootPath"
#define kDebugLogging		@"DebugLogging"
#define kPersistentDomain	@"com.alleus.TranspRAR.pref"

@interface TranspRARPref ()

- (void)checkForService:(NSTimer *)timer;

@end



@implementation TranspRARPref

- (void) mainViewDidLoad
{
	classBundle = [[NSBundle bundleForClass:[self class]] retain];
	/*updater = [[SUUpdater updaterForBundle:classBundle] retain];
	[updater setDelegate:self];*/
}

- (void)didSelect {
	// Notification for lost connection
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionDied:) name:NSConnectionDidDieNotification object:nil];
	
	// Get initial connection
	[self checkForService:nil];
	[self updateServerStatus];
	
	// Set info text
	NSString *infoRTFPath = [classBundle pathForResource:@"Info" ofType:@"rtf"];
	[infoLabel setAttributedStringValue:[[NSAttributedString alloc] initWithRTF:[NSData dataWithContentsOfFile:infoRTFPath] documentAttributes:nil]];
	[infoLabel setAllowsEditingTextAttributes:YES];
	
	// Get auto launch state
	NSString *servicePath = [classBundle pathForResource:@"TranspRAR" ofType:@"app"];
	BOOL startOnLogin = NO;
	NSArray *loginItems = (NSArray *)CFPreferencesCopyAppValue(CFSTR("AutoLaunchedApplicationDictionary"), CFSTR("loginwindow"));
	for (NSDictionary *loginItem in loginItems) {
		if ([[loginItem objectForKey:@"Path"] isEqualToString:servicePath]) {
			startOnLogin = YES;
			break;
		}
	}
	[autoLaunchSwitch setState:(startOnLogin)?NSOnState:NSOffState];
	
	// Get root path
	NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:kPersistentDomain];
	[debugLoggingSwitch setState:([[defaults objectForKey:kDebugLogging] boolValue])?NSOnState:NSOffState];
	NSString *rootPath = [defaults objectForKey:kRootPath];
	
	if (!rootPath) {
		// First time pref pane is launched, set root path to home directory
		rootPath = [@"~" stringByExpandingTildeInPath];
		
		NSMutableDictionary *mutableDefaults = (defaults)?[defaults mutableCopy]:[[NSMutableDictionary alloc] init];
		[mutableDefaults setObject:rootPath forKey:kRootPath];
		[[NSUserDefaults standardUserDefaults] setPersistentDomain:mutableDefaults forName:kPersistentDomain];
		[mutableDefaults release];
	}
	
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:rootPath];
	[icon setSize:NSSizeFromCGSize(CGSizeMake(16, 16))];
	[rootPathMenuItem setImage:icon];
	[rootPathMenuItem setTitle:[rootPath lastPathComponent]];
}

- (void)checkForService:(NSTimer *)timer {
	serverObject = [NSConnection rootProxyForConnectionWithRegisteredName:@"TranspRAR" host:nil];
	if (serverObject) {
		[serverObject setProtocolForProxy:@protocol(ACTranspRARServiceProtocol)];
		[self updateServerStatus];
		[timer invalidate];
	}
}

- (void)didUnselect {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSConnectionDidDieNotification object:nil];
}

- (void)connectionDied:(NSNotification *)notification {
	serverObject = nil;
	[self updateServerStatus];
}

- (void)updateServerStatus {
	[progressIndicator stopAnimation:nil];
	if (serverObject) {
		[startStopButton setTitle:@"Stop TranspRAR"];
		[statusLabel setStringValue:@"TranspRAR is running."];
		[rootPathPopUp setEnabled:NO];
		[debugLoggingSwitch setEnabled:NO];
	} else {
		[startStopButton setTitle:@"Start TranspRAR"];
		[statusLabel setStringValue:@"TranspRAR is stopped."];
		[rootPathPopUp setEnabled:YES];
		[debugLoggingSwitch setEnabled:YES];
	}
}

/*// Return YES to delay the relaunch until you do some processing; invoke the given NSInvocation to continue.
- (BOOL)updater:(SUUpdater *)updater shouldPostponeRelaunchForUpdate:(SUAppcastItem *)update untilInvoking:(NSInvocation *)invocation {
	updateRelaunchInvocation = [invocation retain];
	
	return YES;
}*/

- (IBAction)startStopButtonPressed:(id)sender {
	if (serverObject) {
		[progressIndicator startAnimation:nil];
		[statusLabel setStringValue:@"Stopping TranspRAR..."];
		[serverObject terminate];
	} else {
		[progressIndicator startAnimation:nil];
		[statusLabel setStringValue:@"Starting TranspRAR..."];
		NSBundle *serviceBundle = [NSBundle bundleWithPath:[classBundle pathForResource:@"TranspRAR" ofType:@"app"]];
		[[NSWorkspace sharedWorkspace] launchApplication:[serviceBundle executablePath]];
		[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkForService:) userInfo:nil repeats:YES];
	}
}

- (IBAction)autoLaunchSwitchChanged:(id)sender {
	NSString *servicePath = [classBundle pathForResource:@"TranspRAR" ofType:@"app"];
	NSInteger loginItemIndex = NSNotFound;
	
	NSArray *loginItems = (NSArray *)CFPreferencesCopyAppValue(CFSTR("AutoLaunchedApplicationDictionary"), CFSTR("loginwindow"));
	
	NSUInteger i, count = [loginItems count];
	for (i = 0; i < count; i++) {
		NSDictionary *loginItem = [loginItems objectAtIndex:i];
		if ([[loginItem objectForKey:@"Path"] isEqualToString:servicePath]) {
			loginItemIndex = i;
			break;
		}
	}
	
	NSMutableArray *mutableLoginItems = [loginItems mutableCopy];
	
	if ([sender state] == NSOnState && loginItemIndex == NSNotFound) {
		[mutableLoginItems addObject:[NSDictionary dictionaryWithObject:servicePath forKey:@"Path"]];
	} else if ([sender state] == NSOffState && loginItemIndex != NSNotFound) {
		[mutableLoginItems removeObjectAtIndex:loginItemIndex];
	}
	
	CFPreferencesSetAppValue(CFSTR("AutoLaunchedApplicationDictionary"), mutableLoginItems, CFSTR("loginwindow"));
	CFPreferencesAppSynchronize(CFSTR("loginwindow"));
}

- (IBAction)rootPathPopUpChanged:(NSPopUpButton *)sender {

	if ([sender selectedItem] != rootPathMenuItem) {
		// Get root path
		NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:kPersistentDomain];
		NSString *rootPath = [defaults objectForKey:kRootPath];
		
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setShowsHiddenFiles:YES];
		[openPanel setCanChooseDirectories:YES];
		[openPanel setCanCreateDirectories:YES]; // Added by DustinVoss
		[openPanel setPrompt:@"Choose folder"]; // Should be localized
		[openPanel setCanChooseFiles:NO];
		[openPanel setDirectoryURL:[NSURL fileURLWithPath:rootPath]];
		if ([openPanel runModal] == NSFileHandlingPanelOKButton) {
			rootPath = [[openPanel directoryURL] path];
			
			NSMutableDictionary *mutableDefaults = (defaults)?[defaults mutableCopy]:[[NSMutableDictionary alloc] init];
			[mutableDefaults setObject:rootPath forKey:kRootPath];
			[[NSUserDefaults standardUserDefaults] setPersistentDomain:mutableDefaults forName:kPersistentDomain];
			[mutableDefaults release];
			
			NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:rootPath];
			[icon setSize:NSSizeFromCGSize(CGSizeMake(16, 16))];
			[rootPathMenuItem setImage:icon];
			[rootPathMenuItem setTitle:[rootPath lastPathComponent]];
		}
		[sender selectItem:rootPathMenuItem];
	}
}

- (IBAction)debugLoggingSwitchChanged:(id)sender {
	NSDictionary *defaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:kPersistentDomain];
	NSMutableDictionary *mutableDefaults = (defaults)?[defaults mutableCopy]:[[NSMutableDictionary alloc] init];
	[mutableDefaults setObject:[NSNumber numberWithBool:([sender state] == NSOnState)] forKey:kDebugLogging];
	[[NSUserDefaults standardUserDefaults] setPersistentDomain:mutableDefaults forName:kPersistentDomain];
	[mutableDefaults release];
}

- (SUUpdater *)updater {
	return [SUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];
}

@end
