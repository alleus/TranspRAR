//
//  TranspRARPrefPref.h
//  TranspRARPref
//
//  Created by Martin Alléus on 2010-09-10.
//  Copyright (c) 2010 Appcorn AB. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>
#import <Sparkle/SUUpdater.h>


@protocol ACTranspRARServiceProtocol

- (oneway)terminate;

@end


@interface TranspRARPref : NSPreferencePane <NSOpenSavePanelDelegate>
{
	NSBundle		*classBundle;
	//SUUpdater		*updater;
	NSInvocation	*updateRelaunchInvocation;
	
	IBOutlet NSTextField	*statusLabel;
	IBOutlet NSPopUpButton	*rootPathPopUp;
	IBOutlet NSMenuItem		*rootPathMenuItem;
	IBOutlet NSButton		*startStopButton;
	IBOutlet NSTextField	*infoLabel;
	IBOutlet NSButton		*autoLaunchSwitch;
	IBOutlet NSButton		*debugLoggingSwitch;
	IBOutlet NSButton		*labelSwitch;
	IBOutlet NSProgressIndicator	*progressIndicator;
	
	NSDistantObject<ACTranspRARServiceProtocol>	*serverObject;
}

@property (readonly) SUUpdater *updater;

- (void)mainViewDidLoad;
- (void)updateServerStatus;

- (IBAction)startStopButtonPressed:(id)sender;
- (IBAction)autoLaunchSwitchChanged:(id)sender;
- (IBAction)rootPathPopUpChanged:(id)sender;
- (IBAction)debugLoggingSwitchChanged:(id)sender;
- (IBAction)labelSwitchChanged:(id)sender;


@end
