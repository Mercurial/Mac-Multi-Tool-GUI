//
//  DiskArbApp.h
//  DiskArbTest
//
//  Created by Kristopher Scruggs on 2/10/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "CNOutlineView.h"
#import "Disk.h"

enum {
    kDiskUnmountOptionDefault = 0x00000000,
    kDiskUnmountOptionForce = 0x00080000,
    kDiskUnmountOptionWhole = 0x00000001
};

@interface DiskUtilityController : NSViewController <NSUserNotificationCenterDelegate> {
    
}

@property (weak) IBOutlet CNOutlineView *diskView;
@property (weak) IBOutlet NSButton *verifyDiskButton;
@property (weak) IBOutlet NSButton *repairDiskButton;
@property (weak) IBOutlet NSButton *rebuildKextCacheButton;
@property (weak) IBOutlet NSButton *repairPermissionsButton;
@property (weak) IBOutlet NSProgressIndicator *taskRunning;
@property IBOutlet NSTextView *outputText;

@property (assign) IBOutlet NSButton *mountButton;
@property (assign) IBOutlet NSTextField *mountText;
@property (assign) IBOutlet NSButton *eraseButton;
@property (assign) IBOutlet NSButton *partitionButton;
@property (assign) IBOutlet NSButton *diskImageButton;
@property (assign) IBOutlet NSMenu *diskImageMenu;

@property (assign) IBOutlet NSView *blankImageView;

@property (assign) IBOutlet NSWindow *createImageModalWindow;
@property (assign) IBOutlet NSImageView *createImageModalImage;
@property (assign) IBOutlet NSTextField *createImageModalNameText;
@property (assign) IBOutlet NSTextField *createImageModalSubText;
@property (assign) IBOutlet NSTextView *createImageModalDetailText;
@property (assign) IBOutlet NSButton *createImageModalDone;
@property (assign) IBOutlet NSProgressIndicator *createImageModalProgress;

@property (assign) IBOutlet NSTextField *nameTextField;
@property (assign) IBOutlet NSPopUpButton *sizePopup;
@property (assign) IBOutlet NSTextField *sizeTextField;
@property (assign) IBOutlet NSPopUpButton *sizeTextPopup;
@property (assign) IBOutlet NSPopUpButton *formatPopup;
@property (assign) IBOutlet NSPopUpButton *encryptionPopup;
@property (assign) IBOutlet NSPopUpButton *partitionsPopup;
@property (assign) IBOutlet NSPopUpButton *imageFormatPopup;

@property (assign) IBOutlet NSMenuItem *blankImage;
@property (assign) IBOutlet NSMenuItem *folderImage;
@property (assign) IBOutlet NSMenuItem *diskImage;

@property (assign) IBOutlet NSTextField *diskNameField;
@property (assign) IBOutlet NSTextField *diskInfoField;
@property (assign) IBOutlet NSImageView *diskImageField;

@property (assign) IBOutlet NSTextField *mountPointText;
@property (assign) IBOutlet NSTextField *capacityText;
@property (assign) IBOutlet NSTextField *usedText;
@property (assign) IBOutlet NSTextField *uuidText;
@property (assign) IBOutlet NSTextField *typeText;
@property (assign) IBOutlet NSTextField *availableText;
@property (assign) IBOutlet NSTextField *deviceText;

@property (assign) IBOutlet NSTextField *mountPointPartitionMap;
@property (assign) IBOutlet NSTextField *usedLocation;
@property (assign) IBOutlet NSTextField *typeConnection;
@property (assign) IBOutlet NSTextField *availableChildren;

@property (assign) IBOutlet NSProgressIndicator *diskSize;


@property NSArray *disks;
@property NSMutableArray *tasksToRun;
@property Disk *currentDisk;
@property NSRect selected;
@property BOOL _shouldResize;
@property BOOL runningTask;
@property NSArray *formatTypes;
@property NSArray *encryptionTypes;
@property NSArray *partitionTypes;
@property NSArray *imageTypes;
@property NSArray *cdSizeTypes;

//Work with this more later - right now just a placeholder.
@property BOOL currentlyWorking;

- (BOOL)shouldResize;

@end
