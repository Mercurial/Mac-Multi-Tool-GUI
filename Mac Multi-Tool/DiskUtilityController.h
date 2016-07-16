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

//New Convert Image SavePanel Stuff
@property (assign) IBOutlet NSView *convertImageView;
@property (assign) IBOutlet NSTextField *convertVolumeNameText;
@property (assign) IBOutlet NSPopUpButton *convertFormatPopup;
@property (assign) IBOutlet NSPopUpButton *convertEncryptionPopup;
@property (assign) IBOutlet NSPopUpButton *convertPartitionsPopup;
@property (assign) IBOutlet NSPopUpButton *convertImageFormatPopup;
@property (assign) IBOutlet NSSlider *convertCompressionSlider;
@property (assign) IBOutlet NSTextField *convertCompressionText;
@property (assign) IBOutlet NSButton *convertAdminPrivs;
//@property (assign) IBOutlet NSButton *convertRemoveExtButton;

//Convert Instead Window
@property (assign) IBOutlet NSWindow *convertInsteadWindow;
@property (assign) IBOutlet NSTextField *convertInsteadText;

//Disk Image Locked Window
@property (assign) IBOutlet NSWindow *convertEncryptedWindow;
@property (assign) IBOutlet NSTextField *convertEncryptedText;

//New Blank Image SavePanel Stuff
@property (assign) IBOutlet NSView *blankImageView;
@property (assign) IBOutlet NSTextField *nameTextField;
@property (assign) IBOutlet NSPopUpButton *sizePopup;
@property (assign) IBOutlet NSTextField *sizeTextField;
@property (assign) IBOutlet NSPopUpButton *sizeTextPopup;
@property (assign) IBOutlet NSPopUpButton *formatPopup;
@property (assign) IBOutlet NSPopUpButton *encryptionPopup;
//@property (assign) IBOutlet NSSecureTextField *encryptionSecureField;
//@property (assign) IBOutlet NSTextField *encryptionTextField;
//@property (assign) IBOutlet NSButton *encryptionShowButton;
@property (assign) IBOutlet NSPopUpButton *partitionsPopup;
@property (assign) IBOutlet NSPopUpButton *imageFormatPopup;
@property (assign) IBOutlet NSButton *blankAdminPrivs;

//######################################################
//###              Main Window stuff                 ###
//######################################################
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

//Disk info top
@property (assign) IBOutlet NSTextField *diskNameField;
@property (assign) IBOutlet NSTextField *diskInfoField;
@property (assign) IBOutlet NSImageView *diskImageField;

//New image menu items
@property (assign) IBOutlet NSMenuItem *blankImage;
@property (assign) IBOutlet NSMenuItem *folderImage;
@property (assign) IBOutlet NSMenuItem *diskImage;

//Disk info main area
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
//######################################################
//###               End Main Window                  ###
//######################################################


//Password critical sheet window stuff
@property (assign) IBOutlet NSWindow *passWindow;
@property (assign) IBOutlet NSTextField *passNoBlank;
@property (assign) IBOutlet NSSecureTextField *passOneSecureField;
@property (assign) IBOutlet NSSecureTextField *passTwoSecureField;
@property (assign) IBOutlet NSTextField *passOneTextField;
@property (assign) IBOutlet NSTextField *passTwoTextField;
@property (assign) IBOutlet NSButton *passShowButton;

//Internal variables - that I guess are external
//too or something...
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
@property NSArray *convertImageTypes;
@property NSArray *cdSizeTypes;

@property NSSavePanel *imageBlankSave;
@property NSSavePanel *imageConvertSave;

@property NSString *selectedDiskName;

@property NSURL *convertURL;

//Work with this more later - right now just a placeholder.
@property BOOL currentlyWorking;

- (BOOL)shouldResize;

@end
