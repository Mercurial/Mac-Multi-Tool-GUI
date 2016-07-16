//
//  DiskArbApp.m
//  DiskArbTest
//
//  Created by Kristopher Scruggs on 2/10/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import "DiskUtilityController.h"
#import "Arbitration.h"
#import "AAPLImageAndTextCell.h"
#import "STPrivilegedTask.h"
#import "CNCreateDiskController.h"
#import "CNModalPassController.h"
#import "CNPopoverController.h"

@import ServiceManagement;
@import AppKit;

#pragma mark -

#define COLUMNID_NAME               @"Name"
#define IMAGE_PAD                   3

static NSSize imageSize;

@interface DiskUtilityController ()

@property (strong) CNCreateDiskController *diskController;
@property (strong) CNModalPassController *passController;
@property (strong) CNPopoverController *popoverViewController;
@property (strong) NSWindow *detachedWindow;

@end

#pragma mark -

@implementation DiskUtilityController

@synthesize _shouldResize;

- (id)init {
    if (self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil]) {
        
        // Don't resize this window
        _shouldResize = YES;
        
        // Register default preferences - if they exist
        _currentDisk = nil;
        _runningTask = NO;
        [_taskRunning setUsesThreadedAnimation:YES];
        _tasksToRun = [[NSMutableArray alloc] init];
        
        //Setup blank image stuff
        self.formatTypes = [NSArray arrayWithObjects:       @"Journaled HFS+",
                                                            @"Case-sensitive Journaled HFS+",
                                                            @"MS-DOS FAT32",
                                                            @"ExFAT",
                                                            nil];
        self.encryptionTypes = [NSArray arrayWithObjects:   @"none",
                                                            @"AES-128",
                                                            @"AES-256",
                                                            nil];
        self.partitionTypes = [NSArray arrayWithObjects:    @"ISOCD",
                                                            @"SPUD",
                                                            @"GPTSPUD",
                                                            @"MBRSPUD",
                                                            @"NONE",
                                                            nil];
        self.imageTypes = [NSArray arrayWithObjects:        @"SPARSEBUNDLE",
                                                            @"SPARSE",
                                                            @"UDIF",
                                                            @"UDTO",
                                                            nil];
        self.cdSizeTypes = [NSArray arrayWithObjects:       @"177m",
                                                            @"650m",
                                                            @"700m",
                                                            @"2.5g",
                                                            @"4.6g",
                                                            @"8.3g",
                                                            nil];
        
        //Setup convert image stuff
        self.convertImageTypes = [NSArray arrayWithObjects: @"UDRW",    //UDIF read/write
                                                            @"UDRO",    //UDIF read-only
                                                            @"UDCO",    //UDIF ADC-compressed
                                                            @"UDZO",    //UDIF zlib-compressed
                                                            @"UDBZ",    //UDIF bzip2-compressed
                                                            @"UDTO",    //DVD/CD-R master
                                                            @"UDSP",    //SPARSE
                                                            @"UDSB",    //SPARSEBUNDLE
                                                            nil];
        
        
        // Disk Arbitration
        RegisterDA();
        
        // App & Workspace Notification
        [self registerSession];
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    }
    
    return self;
}

- (BOOL)shouldResize {
    return _shouldResize;
}

#pragma mark - View Setup

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    //Set our image size here
    imageSize = NSMakeSize(16, 16);
    
    [_outputText setFont:[NSFont fontWithName:@"Menlo" size:11]];
    
    _currentlyWorking = NO;
    
    
    [_diskView setDataSource:(id<NSOutlineViewDataSource>)self];
    [_diskView setDelegate:(id<NSOutlineViewDelegate>)self];
    
    //Set up for receiving double-click notifications
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outlineViewDoubleClick:) name:@"OutlineViewDoubleClick" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outlineViewSelected:) name:@"OutlineViewSelected" object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(privilegedTaskFinished:) name:STPrivilegedTaskDidTerminateNotification object:nil];

    
    //_disks = [[CNDiskList sharedList] getOutlineViewList];
    
    //_disks = [[CNDiskList sharedList] getAllDisksAndPartitionsList];
    
    //NSLog(@"%@", [[[[_disks objectAtIndex:0] getChildren] objectAtIndex:1] getObjects]);
    
    
    
    // Clear the text fields in the window
    [self clearMainWindow];
    
    [_uuidText setSelectable:YES];
    
    //[_diskSize NSProgressIndicatorThickness]
    
    //[NSApp setMainMenu:_mainMenu];
    
    
    //Setup our popover button
    _popoverViewController = [[NSClassFromString(@"CNPopoverController") alloc] init];
    
    NSRect frame = self.popoverViewController.view.bounds;
    NSUInteger styleMask = NSTitledWindowMask + NSClosableWindowMask;
    NSRect rect = [NSWindow contentRectForFrameRect:frame styleMask:styleMask];
    _detachedWindow = [[NSWindow alloc] initWithContentRect:rect styleMask:styleMask backing:NSBackingStoreBuffered defer:YES];
    self.detachedWindow.contentViewController = self.popoverViewController;
    self.detachedWindow.releasedWhenClosed = NO;
    
    
    [_diskView reloadData];
    //Load outlineview expanded.
    [_diskView expandItem:nil expandChildren:YES];
}

#pragma mark - OutlineView Click/Double-Click Methods

- (void)outlineViewDoubleClick:(id)note {
    /*//Load the disk that we just double clicked.
    //_disks = [[CNDiskList sharedList] getDiskViewList:[note userInfo]];
    //[_diskView reloadData];
    _selected = [[[note userInfo] objectForKey:@"Rect"] rectValue];
    CNDiskRep *diskForInfo = [[note userInfo] objectForKey:@"Item"];
    NSString *diskInfo = [[CNDiskList sharedList] getStringForDisk:diskForInfo];
    NSString *diskName = [diskForInfo objectForKey:@"Name"];
    if ([diskName isEqualToString:@""]) {
        diskName=@"None";
    }
    
    [_popoverViewController setText:diskInfo];
    [_popoverViewController setTitle:diskName];
    [self showPopoverAction:_diskView];*/
}

- (void)outlineViewSelected:(id)note {
    if (!_runningTask) {
        // Reload all our info
        [self respondToSelectedItem:_diskView];
    }
}

#pragma mark - UI Methods

- (void)respondToSelectedItem:(NSOutlineView *)outlineView {
    
    [_rebuildKextCacheButton setEnabled:YES];
    
    //Temp perma-disable for the new image button.  WIP
    [_diskImageButton setEnabled:YES];
    //[_diskImageButton setEnabled:NO];
    
    [_mountButton setEnabled:NO];
   
    id selectedItem = [outlineView itemAtRow:[outlineView selectedRow]];
    if ([selectedItem isKindOfClass:[Disk class]]) {
        // Let's enable/disable buttons based on disk info
        Disk *disk = selectedItem;
        _currentDisk = disk;
        [_repairDiskButton setEnabled:YES];
        [_verifyDiskButton setEnabled:YES];
        //[_ejectButton setEnabled:NO];
        [_mountText setStringValue:@"Mount"];
        [_repairPermissionsButton setEnabled:NO];
        
        
        [disk isWriteable] ? [self.eraseButton setEnabled:YES] : [self.eraseButton setEnabled:NO];
        if ([disk isBootVolume] || [disk isBootDisk]) {
            //Disable buttons for boot disk/volume
            [self.eraseButton setEnabled:NO];
            [self.partitionButton setEnabled:NO];
            [self.repairDiskButton setEnabled:NO];
            [self.repairPermissionsButton setEnabled:YES];
        }
        
        if ([disk isMounted]) {
            [_mountText setStringValue:@"Unmount"];
            if (!disk.isBootVolume) {
                //[_ejectButton setEnabled:YES];
                [_mountButton setEnabled:YES];
            } else {
                [_repairPermissionsButton setEnabled:YES];
                [_repairDiskButton setEnabled:NO];
            }
        } else if ([disk isMountable]) {
            [_mountButton setEnabled:YES];
        } else if ([disk isWholeDisk] && ([disk isEjectable] || [disk isRemovable])) {
            BOOL anyMounted = NO;
            [_mountButton setEnabled:YES];
            for (Disk *child in [disk children]) {
                // Find out if all disks are unmounted
                if ([child isMounted]) anyMounted = YES;
            }
            if (anyMounted) {
                [_mountText setStringValue:@"Unmount"];
            } else {
                //[_mountText setStringValue:@"Mount"];
            }
        }
        
        // Grab info from disk
        // Setup top & bottom of window info
        //if (![[disk volumePath] isEqualToString:@"/"]) {
            if ([disk volumeName]) {
                [_diskNameField setStringValue:[disk volumeName]];
                [_diskImage setTitle:[NSString stringWithFormat:@"Image From %@...", [disk volumeName]]];
                self.selectedDiskName = [disk volumeName];
                [_diskImage setEnabled:YES];
            } else if ([disk mediaName]) {
                [_diskNameField setStringValue:[disk mediaName]];
                [_diskImage setTitle:[NSString stringWithFormat:@"Image From %@...", [disk mediaName]]];
                self.selectedDiskName = [disk mediaName];
                [_diskImage setEnabled:YES];
            }
        //} else {
           // [_diskImage setTitle:@"Can't create image from boot disk..."];
            //[_diskImage setEnabled:NO];
        //}
        
        // Get the icon
        [_diskImageField setImage:disk.icon];
        
        // Build the info string - Size Connection FS
        NSString *fs = @"No File System";
        if ([disk volumeFS]) fs = [disk volumeFS];
        NSString *infoString = [NSString stringWithFormat:@"%@ - %@ - %@ (%@)", [disk formattedSize], [disk deviceProtocol], fs, disk.BSDName];
        [_diskInfoField setStringValue:infoString];
        
        if ([disk isWholeDisk]) {
            // Set our labels first, then the values
            [_mountPointPartitionMap setStringValue:@"Partition Map:"];
            [_usedLocation setStringValue:@"Location:"];
            [_typeConnection setStringValue:@"Connection:"];
            [_availableChildren setStringValue:@"Children:"];
            
            [_mountPointText setStringValue:[disk mediaContent] ?: @"Unknown"];
            [_capacityText setStringValue:[disk formattedSize] ?: @"Unknown"];
            [_typeText setStringValue:[disk deviceProtocol] ?: @"Unknown"];
            [_usedText setStringValue:[disk isInternal] ? @"Internal" : @"External"];
            [_uuidText setStringValue:@"N/A"]; // Empty string for whole disk
            [_availableText setStringValue:[NSString stringWithFormat:@"%lu", [disk.children count]]];
            
            [_diskSize setMaxValue:[[disk mediaSize] doubleValue]];
            [_diskSize setDoubleValue:0];
            [_diskSize incrementBy:[[disk mediaSize] doubleValue]];
            
        } else {
            // Set our labels first, then the values
            [_mountPointPartitionMap setStringValue:@"Mount Point:"];
            [_usedLocation setStringValue:@"Used:"];
            [_typeConnection setStringValue:@"Type:"];
            [_availableChildren setStringValue:@"Available:"];
            
            [_mountPointText setStringValue:[disk volumePath] ?: @"Not Mounted"];
            [_capacityText setStringValue:[disk formattedSize] ?: @"Unknown"];
            [_usedText setStringValue:[disk formattedUsedSpace] ?: @"Unknown"];
            [_typeText setStringValue:[disk volumeFS] ?: @"Unknown"];
            [_availableText setStringValue:[disk formattedFreeSpace] ?: @"Unknown"];
            [_uuidText setStringValue:disk.diskUUID ?: @"Unknown"];
            
            [_diskSize setMaxValue:[[disk mediaSize] doubleValue]];
            [_diskSize setDoubleValue:0];
            [_diskSize incrementBy:[[disk usedSpace] doubleValue]];
        }
        [_deviceText setStringValue:disk.BSDName ?: @"No BSD Name"];
    } else {
        [self clearMainWindow];
        _currentDisk = nil;
    }
}

-(IBAction)rebuildKextCache:(id)sender {
    NSLog(@"Rebuild Kext Cache");
    // We need to run a couple terminal commands to get this done
    // rm -r /System/Library/Caches/com.apple.kext.caches
    // touch /System/Library/Extensions
    // kextcache -update-volume /
    //
    //One after the other - and all with admin privs.
    
    //Disable buttons
    //[self disableButtons];
    
    //[self appendOutput:@"Rebuilding kext cache...\n"];
    
    // rm -r /System/Library/Caches/com.apple.kext/caches
    NSString *path = @"/bin/rm";
    NSArray *args = [NSArray arrayWithObjects:@"-r", @"/System/Library/Caches/com.apple.kext.caches", nil];
    [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Removing /System/Library/Caches/com.apple.kext.caches...\n", @"Start Message", nil]];
    
    // touch /System/Library/Extensions
    path = @"/usr/bin/touch";
    args = [NSArray arrayWithObjects:@"/System/Library/Extensions", nil];
    [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Touching /System/Library/Extensions...\n", @"Start Message", nil]];
    
    // kextcache -update-volume /
    path = @"/usr/sbin/kextcache";
    args = [NSArray arrayWithObjects:@"-update-volume", @"/", nil];
    [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Rebuilding Kext Cache...\n", @"Start Message", @"Complete.\n\n", @"End Message", nil]];
    
    [self launchNextTask];
}

-(IBAction)repairPermissions:(id)sender {
    NSLog(@"Repair Permissions");
    if (_currentDisk != nil && [_currentDisk volumePath]) {
        NSLog(@"Disk: %@", [_currentDisk volumePath]);
        //Build our privileged task for verifying disk
        
        //Disable buttons
        //[self disableButtons];
        
        //[self appendOutput:@"Repairing permissions...\n"];
        
        //[self launchPTWithPath:@"/usr/libexec/repair_packages" arguments:[NSArray arrayWithObjects:@"--repair", @"--standard-pkgs", @"--volume", [_currentDisk volumePath], nil]];*/
        NSString *path = @"/usr/libexec/repair_packages";
        NSArray *args = [NSArray arrayWithObjects:@"--repair", @"--standard-pkgs", @"--volume", [_currentDisk volumePath], nil];
        [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Complete.\n\n", @"End Message", @"Repairing permissions...\n", @"Start Message", nil]];
        [self launchNextTask];
    }
}

-(IBAction)verifyDisk:(id)sender {
    NSLog(@"Verify Disk");
    if (_currentDisk != nil) {
        NSLog(@"Disk: %@", _currentDisk.BSDName);
        //Build our privileged task for verifying disk
        
        NSString *task = @"verifyVolume";
        if ([_currentDisk isWholeDisk]) {
            task = @"verifyDisk";
        }
        
        //Disable buttons
        //[self disableButtons];
        
        //[self launchPTWithPath:@"/usr/sbin/diskutil" arguments:[NSArray arrayWithObjects:task, _currentDisk.BSDName, nil]];
        
        NSString *path = @"/usr/sbin/diskutil";
        NSArray *args = [NSArray arrayWithObjects:task, _currentDisk.BSDName, nil];
        [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Complete.\n\n", @"End Message", nil]];
        [self launchNextTask];
    }
}

-(IBAction)repairDisk:(id)sender {
    NSLog(@"Repair Disk");
    if (_currentDisk != nil) {
        NSLog(@"Disk: %@", _currentDisk.BSDName);
        //Build our privileged task for repairing disk
        
        if (![_currentDisk isWholeDisk]) {
            //task = @"repairDisk";
        
        
            //Disable buttons
            //[self disableButtons];
        
            //[self launchPTWithPath:@"/usr/sbin/diskutil" arguments:[NSArray arrayWithObjects:task, _currentDisk.BSDName, nil]];
        
            NSString *path = @"/usr/sbin/diskutil";
            NSArray *args = [NSArray arrayWithObjects:@"repairVolume", _currentDisk.BSDName, nil];
            [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Complete.\n\n", @"End Message", nil]];
            [self launchNextTask];
        } else {
            //Whole disk - display warning
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Warning:"];
            [alert setInformativeText:[NSString stringWithFormat:@"Repairing the partition map might erase %@, proceed?", _currentDisk.BSDName]];
            [alert setAlertStyle:NSWarningAlertStyle];
            
            //Attach sheet
            [alert beginSheetModalForWindow:[[self view] window] modalDelegate:self didEndSelector:@selector(repairAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        }
    }
}

- (void)repairAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        //NSLog(@"OK");
        NSString *path = @"/bin/sh";
        NSArray *args = [NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"echo y | /usr/sbin/diskutil repairDisk %@", _currentDisk.BSDName], nil];
        [_tasksToRun addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"Path", args, @"Args", @"Complete.\n\n", @"End Message", nil]];
        [self launchNextTask];
    } else {
        //NSLog(@"Cancel");
        [self appendOutput:[NSString stringWithFormat:@"User canceled repair of %@.\n\n", _currentDisk.BSDName]];
    }
}

- (IBAction)toggleMount:(id)sender {
    id selectedItem = [_diskView itemAtRow:[_diskView selectedRow]];
    Disk *disk = selectedItem;
    if (!disk) return;
    
    if ([[_mountText stringValue] isEqualToString:@"Mount"]) {
        if ([disk isWholeDisk]) {
            [disk mountWhole];
        } else {
            [disk mount];
        }
    } else {
        if ([selectedItem isKindOfClass:[Disk class]]) {
            if ([disk isWholeDisk] && [disk isEjectable]) {
                [self performEject:disk];
            } else {
                [disk unmountWithOptions: disk.isWholeDisk ?  kDiskUnmountOptionWhole : kDiskUnmountOptionDefault];
            }
        }
    }
}

- (IBAction)mountDisk:(id)sender {
    id selectedItem = [_diskView itemAtRow:[_diskView selectedRow]];
    if ([selectedItem isKindOfClass:[Disk class]]) {
        Disk *disk = selectedItem;
        
        /*if ([disk isWholeDisk]) {
            NSLog(@"diskutil mountDisk %@", disk.BSDName);
        } else {
            NSLog(@"diskutil mount %@", disk.BSDName);
        }*/
        if ([disk isWholeDisk]) {
            [disk mountWhole];
        } else {
            [disk mount];
        }
    }
}

- (IBAction)ejectDisk:(id)sender {
    id selectedItem = [_diskView itemAtRow:[_diskView selectedRow]];
    if ([selectedItem isKindOfClass:[Disk class]]) {
        Disk *disk = selectedItem;
        
        if (!disk) return;
        
        if ([disk isWholeDisk] && [disk isEjectable]) {
            [self performEject:disk];
        } else {
            [disk unmountWithOptions: disk.isWholeDisk ?  kDiskUnmountOptionWhole : kDiskUnmountOptionDefault];
        }
        /*if ([disk isWholeDisk]) {
            NSLog(@"diskutil unmountDisk %@", disk.BSDName);
        } else {
            NSLog(@"diskutil unmount %@", disk.BSDName);
        }*/
    }
}

- (void)performEject:(Disk *)disk {
    BOOL waitForChildren = NO;
    
    NSArray *disks;
    if (disk.isWholeDisk && disk.isLeaf)
        disks = [NSArray arrayWithObject:disk];
    else
        disks = disk.children;
    
    for (Disk *aDisk in disks) {
        if (aDisk.isMountable && aDisk.isMounted) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(_childDidAttemptUnmountBeforeEject:)
                                                         name:@"DADiskDidAttemptUnmountNotification"
                                                       object:aDisk];
            [aDisk unmountWithOptions:0];
            waitForChildren = YES;
        }
    }
    
    if (!waitForChildren) {
        if (disk.isEjectable)
            [disk eject];
    }
}

-(IBAction)diskImageClick:(id)sender {
    //Show our menu over our new disk image button.
    NSButton * b = (NSButton*)sender;
    NSPoint l = [ self convertPointToScreen:b.frame.origin ];
    
    //Perma-disable below
    //[_blankImage setEnabled:NO];
    [_folderImage setEnabled:YES];
    //[_diskImage setEnabled:NO];
    
    [ _diskImageMenu popUpMenuPositioningItem:nil atLocation:l inView:nil ];
}

- (IBAction)diskImageEncryptionChange:(id)sender {
    NSString *encrypt = [sender titleOfSelectedItem];
    if (![encrypt isEqualToString:@"none"]) {
        //[self.encryptionTextField setEnabled:YES];
        //[self.encryptionSecureField setEnabled:YES];
        //[self.encryptionShowButton setEnabled:YES];
        //Critical sheet - displays over other sheets
        [self resetPassWindow];
        [[[self view] window] beginCriticalSheet:self.passWindow completionHandler:^(NSInteger result) {
            //Handle that shit!
            
            //Actually no - it's handled elsewhere
            
            /*if (result == NSModalResponseOK) {
                //NSLog(@"We got a pass!");
                
            } else {
                //NSLog(@"User cancelled.");
                
            }*/
        }];
    }
}

- (IBAction)okayPass:(id)sender {
    //Check if okay to close first
    NSString *pass1;
    NSString *pass2;
    if ([self.passShowButton state]) {
        pass1 = [self.passOneTextField stringValue];
        pass2 = [self.passTwoTextField stringValue];
    } else {
        pass1 = [self.passOneSecureField stringValue];
        pass2 = [self.passTwoSecureField stringValue];
    }

    if ([pass1 length] <= 0) {
        //Our string is too short!  Let's show our warning text.
        [self.passNoBlank setStringValue:@"Passwords cannot be blank"];
        [self.passNoBlank setHidden:NO];
        NSBeep();
        return;
    }
    
    if (![pass1 isEqualToString:pass2]) {
        //Our strings don't match!
        [self.passNoBlank setStringValue:@"Passwords do not match"];
        [self.passNoBlank setHidden:NO];
        NSBeep();
        return;
    }
    
    //If we made it this far - then our shit is good.
    [[[self view] window] endSheet:self.passWindow returnCode:NSModalResponseOK];
    
}

- (IBAction)cancelPass:(id)sender {
    //Clean up - then cancel
    
    //We canceled - so let's set our encryption to none
    //then have the code respond to the change
    [_encryptionPopup selectItemWithTitle:@"none"];
    [self diskImageEncryptionChange:_encryptionPopup];
    [self.convertEncryptionPopup selectItemWithTitle:@"none"];
    [self diskImageEncryptionChange:self.convertEncryptionPopup];
    
    [[[self view] window] endSheet:self.passWindow returnCode:NSModalResponseCancel];
}

- (IBAction)showPassword:(id)sender {
    if ([self.passShowButton state]) {
        //Show the password
        [self.passOneSecureField setHidden:YES];
        [self.passTwoSecureField setHidden:YES];
        [self.passOneTextField setHidden:NO];
        [self.passTwoTextField setHidden:NO];
        
        [self.passOneTextField setStringValue:[self.passOneSecureField stringValue]];
        [self.passTwoTextField setStringValue:[self.passTwoSecureField stringValue]];
    } else {
        [self.passOneSecureField setHidden:NO];
        [self.passTwoSecureField setHidden:NO];
        [self.passOneTextField setHidden:YES];
        [self.passTwoTextField setHidden:YES];
        
        [self.passOneSecureField setStringValue:[self.passOneTextField stringValue]];
        [self.passTwoSecureField setStringValue:[self.passTwoTextField stringValue]];
    }
}

- (IBAction)diskImageBlankFormatChange:(id)sender {
    //Change from manual size entry to a popup menu if using
    //DVD/CD master image format
    NSString *selected = [_imageFormatPopup titleOfSelectedItem];
    if ([selected isEqualToString:@"DVD/CD master"]) {
        [_sizePopup setHidden:NO];
        [_sizeTextField setHidden:YES];
        [_sizeTextPopup setHidden:YES];
        [self.imageBlankSave setAllowedFileTypes:[NSArray arrayWithObjects:@"cdr",nil]];
    } else {
        [_sizePopup setHidden:YES];
        [_sizeTextField setHidden:NO];
        [_sizeTextPopup setHidden:NO];
        if ([selected isEqualToString:@"sparse bundle disk image"]) {
            [self.imageBlankSave setAllowedFileTypes:[NSArray arrayWithObjects:@"sparsebundle",nil]];
        } else if ([selected isEqualToString:@"sparse disk image"]) {
            [self.imageBlankSave setAllowedFileTypes:[NSArray arrayWithObjects:@"sparseimage",nil]];
        } else {
            [self.imageBlankSave setAllowedFileTypes:[NSArray arrayWithObjects:@"dmg",nil]];
        }
    }
}

- (IBAction)checkBlankSize:(id)sender {
    //We need to check if our size string includes one of the following:
    //
    // B = bytes
    // K, KB = kilobytes
    // M, MB = megabytes
    // G, GB = gigabytes
    // T, TB = terabytes
    // P, PB = petabytes
    // E, EB = exabyte - we're not using this...
    //
    // And whether it is the min size or not
    // Minimum size is 10 MB
    
    
    //This was fixed with an NSNumberFormater - and a popup button
    //that allows for MB, GB, TB
    
    NSString *suffix = [_sizeTextPopup titleOfSelectedItem];
    float size = [_sizeTextField floatValue];
    
    //Check for minimum size (10 MB)
    
    if ([suffix isEqualToString:@"MB"]) {
        if (size < 10) {
            [self sizeTextFieldBeep];
        }
        
    } else if ([suffix isEqualToString:@"GB"]) {
        if (size < 0.001) {
            [self sizeTextFieldBeep];
        }
    } else {
        if (size < 0.000001) {
            [self sizeTextFieldBeep];
        }
    }
    
}

- (IBAction)diskImageBlank:(id)sender {
    //Let's show our save panel sheet
    //Whole disk - display warning
    if (!self.imageBlankSave) {
        self.imageBlankSave = [[NSSavePanel alloc] init];
        [self.imageBlankSave setTitle:@"New Disk Image"];
        [self.imageBlankSave setAllowedFileTypes:[NSArray arrayWithObjects:@"dmg", nil]];
        [self.imageBlankSave setExtensionHidden:NO];
        [self.imageBlankSave setCanSelectHiddenExtension:YES];
        [self.imageBlankSave setAccessoryView:_blankImageView];
    }
    
    [self resetNewBlankImageView];
    
    //Attach sheet
    [self.imageBlankSave beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        //Handle the shit.
        if (result == NSFileHandlingPanelOKButton) {
            //We clicked Okay
            NSURL *theFile = [self.imageBlankSave URL];
            NSLog(@"Saved disk image: %@", theFile);
            
            //Let's get our image type and size and stuff
            
            
            
            //Let's run our modal window to kick some ask
            self.diskController = [[CNCreateDiskController alloc] initWithWindowNibName:@"CNCreateDiskController"];
            
            //This is *ONLY* called to load the window nib.
            //Without it, we couldn't get references to the other parts.
            [self.diskController.window setTitle:@""];
            
            //We need to build our tasklist
            NSString *volName = [self.nameTextField stringValue];
            NSString *name = [NSString stringWithFormat:@"Creating \"%@\"...", volName];
            NSString *fs = [self.formatTypes objectAtIndex:[self.formatPopup indexOfSelectedItem]];
            NSString *size;
             if ([[_imageFormatPopup titleOfSelectedItem] isEqualToString:@"DVD/CD master"]) {
                 size = [self.cdSizeTypes objectAtIndex:[self.sizePopup indexOfSelectedItem]];
             } else {
                 NSString *suffix = [self.sizeTextPopup titleOfSelectedItem];
                 NSString *end = @"m";
                 if ([suffix isEqualToString:@"GB"]) {
                     end = @"g";
                 } else if ([suffix isEqualToString:@"TB"]) {
                     end = @"t";
                 }
                 size = [NSString stringWithFormat:@"%@%@", [self.sizeTextField stringValue], end];
             }
            NSString *encrypt = @"";
            NSString *pass = @"";
            NSString *prefix = @"";
            NSLog(@"Index of encryptitionPopup: %ld", (long)[self.encryptionPopup indexOfSelectedItem]);
            if ([self.encryptionPopup indexOfSelectedItem]) {
                NSLog(@"Encryption!!!");
                //Encryption - let's find out if we have a password
                if ([self.passShowButton state]) {
                    NSLog(@"Show");
                    //We're pulling from the shown text field
                    if (![[self.passOneTextField stringValue] length]) {
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneTextField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.encryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                } else {
                    NSLog(@"Hidden");
                    if (![[self.passOneSecureField stringValue] length]) {
                        //We're pulling from the hidden text field
                        //0 length string = no password = no encryption
                            encrypt = @"";
                    } else {
                            pass = [self.passOneSecureField stringValue];
                            encrypt = [self.encryptionTypes objectAtIndex:[self.encryptionPopup indexOfSelectedItem]];
                            prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                }
            }
            
            //NSString *path = @"/bin/sh";
            //NSArray *args = [NSArray arrayWithObjects:@"-c", [NSString stringWithFormat:@"echo y | /usr/sbin/diskutil repairDisk %@", _currentDisk.BSDName], nil];
            
            // /bin/sh -c echo -n pass can have spaces | /usr/bin/hdiutil create -puppetstrings -fs FS -type TYPE -layout LAYOUT -size SIZE -volname VOLNAME -encryption ENCRYPTION /Path/To/Output/File.dmg
            
            NSString *layout = [self.partitionTypes objectAtIndex:[self.partitionsPopup indexOfSelectedItem]];
            NSString *type = [self.imageTypes objectAtIndex:[self.imageFormatPopup indexOfSelectedItem]];
            
            /*if ([type isEqualToString:@"UDIF"]){
                type = @"";
            } else {
                type = @"-type UDIF ";
            }*/
            
            //Build a string of commands.

            NSString *theCommand = @"";

            if ([encrypt length]) {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"echo \"%@\\0\" | /usr/bin/hdiutil create -ov -puppetstrings -fs \"%@\" -type %@ -layout %@ -size %@ -volname \"%@\" -stdinpass -encryption %@ \"%@\"", pass, fs, type, layout, size, volName, encrypt, [theFile path]]];
            } else {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"/usr/bin/hdiutil create -ov -puppetstrings -fs \"%@\" -type %@ -layout %@ -size %@ -volname \"%@\" \"%@\"",
                                                                  fs, type, layout, size, volName, [theFile path]]];
            }
            //[hdiutilCommand addObject:[theFile path]];
            //theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@" \"%@\"", [theFile path]]];
            
            
            
            //NSString *hdiCommand = [NSString stringWithFormat:@"%@/usr/bin/hdiutil create -puppetstrings -fs %@ -type %@ -layout %@ -size %@ %@%@", prefix, fs, type, layout, size, encrypt, [theFile path]];
            
            NSString *desc = [NSString stringWithFormat:@"%@, %@, %@, %@, %@", type, fs, size, layout, encrypt];
            NSString *start  = [NSString stringWithFormat:@"/bin/sh -c %@\n\n", theCommand];
            
            NSArray *args = [NSArray arrayWithObjects:@"-c", theCommand, nil];
            
            //NSLog(@"Running command: /bin/sh -c %@", theCommand);
            
            //Are we defaulting to admin privs?
            NSString *useAdmin = @"No";
            if ([_blankAdminPrivs state]) useAdmin = @"Yes";
            
            //Create an sh task so we can send a password in if needed.
            
            NSDictionary *command = [NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", @"Path",
                                                                                args, @"Args",
                                                                                name, @"Title",
                                                                                desc, @"Subtext",
                                                                                useAdmin, @"Privilege",
                                                                                @"\nComplete.", @"End Message",
                                                                                start, @"Start Message",
                                                                                nil];
            
            [self.diskController setTaskArray:[NSArray arrayWithObjects:command,nil]];
            
            //Run our task, then display the modal window
            [self.diskController startProcess];
            
            //NSString *command = [NSString stringWithFormat:@"hdiutil create -fs \"%@\" -type %@ -layout %@ -size %@ -volname \"%@\" \"%@\"", fs, type, layout, size, volName, [theFile path]];
            
            
            //Let's let the window handle this now - in the future if there are multiple tasks
            //sent to the modal window - they should complete correctly.
            
            /*[self.diskController.detail setString:command];
            [self.diskController.name setStringValue:name];
            [self.diskController.desc setStringValue:desc];
            [self.diskController.progress setIndeterminate:YES];
            [self.diskController.progress startAnimation:nil];*/
            
            //Build our privileged task and run it
            
            
            [[[self view] window] beginSheet:self.diskController.window  completionHandler:^(NSModalResponse returnCode) {
                NSLog(@"Sheet closed");
                
                //[_createImageModalProgress setIndeterminate:YES];
                //[_createImageModalProgress startAnimation:nil];
                
                switch (returnCode) {
                    case NSModalResponseOK:
                        NSLog(@"Done button tapped in Custom Sheet");
                        break;
                    case NSModalResponseCancel:
                        NSLog(@"Cancel button tapped in Custom Sheet");
                        break;
                        
                    default:
                        break;
                }
            }];
            
        }
        
    }];
    
}

- (IBAction)compressionLevelChanged:(id)sender {
    float compressionLevel = [self.convertCompressionSlider doubleValue];
    NSString *compressionString;
    if (compressionLevel == 1) {
        compressionString = [NSString stringWithFormat:@"%i (fastest)", (int)compressionLevel];
    } else if (compressionLevel < 4) {
        compressionString = [NSString stringWithFormat:@"%i (faster)", (int)compressionLevel];
    } else if (compressionLevel < 7) {
        compressionString = [NSString stringWithFormat:@"%i (moderate)", (int)compressionLevel];
    } else if (compressionLevel < 9) {
        compressionString = [NSString stringWithFormat:@"%i (better)", (int)compressionLevel];
    } else {
        compressionString = [NSString stringWithFormat:@"%i (best)", (int)compressionLevel];
    }
    [self.convertCompressionText setStringValue:compressionString];
}

- (IBAction)convertFormatChanged:(id)sender {
    //Change from manual size entry to a popup menu if using
    //DVD/CD master image format
    NSString *selected = [self.convertImageFormatPopup titleOfSelectedItem];
    [self.convertCompressionSlider setEnabled:NO];
    if ([selected isEqualToString:@"DVD/CD-R master"]) {
        [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"cdr",nil]];
    } else if ([selected isEqualToString:@"sparse bundle disk image"]) {
        [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"sparsebundle",nil]];
    } else if ([selected isEqualToString:@"sparse disk image"]) {
        [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"sparseimage",nil]];
    } else {
        [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"dmg",nil]];
        if ([[self.convertImageFormatPopup titleOfSelectedItem] isEqualToString:@"zlib-compressed disk image"]) {
            [self.convertCompressionSlider setEnabled:YES];
        }
    }
}

- (IBAction)diskImageFolder:(id)sender {
    //We need to do a couple things here -
    //
    //First, we need an Open panel to select the folder we want to create
    //our disk image from
    //
    //Then we need to display a save panel
    //
    //Then we need to actually create our image...
    //
    
    //Step 1 - Open Panel
    //
    NSOpenPanel *openPanel = [[NSOpenPanel alloc] init];
    [openPanel setCanChooseFiles:YES];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    
    [openPanel beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        //Handle that shit
        if (result == NSFileHandlingPanelOKButton) {
            //We got an OK
            
            //Let's check if we've opened a disk image
            //We're looking for a few different extensions:
            //
            //dmg
            //img
            //cdr
            //sparse
            //sparsebundle
            //iso
            //
            //Let's see if we've got any of those
            
            NSArray *extCheck = [NSArray arrayWithObjects:@"dmg", @"img", @"cdr", @"sparse", @"sparsebundle", @"iso", nil];
            
            self.convertURL = [openPanel URL];
            NSString *path = [self.convertURL path];
            NSString *ext = [path pathExtension];
            NSString *nameExt = [path lastPathComponent];
            ext = [ext lowercaseString];
            
            if ([extCheck containsObject:ext]) {
                
                
                //Let's check if it's encrypted
                if ([self isEncrypted:self.convertURL]) {
                    //Encrypted!
                    //Let's build our display string
                    NSString *display = [NSString stringWithFormat:@"It looks like \"%@\" is encrypted.  Would you like to create a new disk image containing \"%@\"? Alternatively, you can click Cancel, mount \"%@\" in the Finder, then create create from source.", nameExt, nameExt, nameExt];
                    
                    [self.convertEncryptedText setStringValue:display];
                    
                    [[[self view] window] beginCriticalSheet:self.convertEncryptedWindow completionHandler:^(NSInteger result) {
                        //Results handled elsewhere
                    }];
                    return;
                    
                } else {
                    //Not Encrypted!
                    //Let's build our display string
                    NSString *display = [NSString stringWithFormat:@"\"%@\" might be a disk image!  Would you like to create a new image containing \"%@\", or convert it?", nameExt, nameExt];
                
                    [self.convertInsteadText setStringValue:display];
                
                    [[[self view] window] beginCriticalSheet:self.convertInsteadWindow completionHandler:^(NSInteger result) {
                        //Results handled elsewhere
                    }];
                }
                
            } else {
                if (self.convertURL) [self createImageURL];
            }
        }
    }];
    
}

- (void)convertImageURL {
    if ([self isEncrypted:self.convertURL]) {
        //Disk image is encrypted - we need to have the
        //user mount it first, then we need them to create
        //a new image from source
        [self.convertEncryptedText setStringValue:[NSString stringWithFormat:@"It appears \"%@\" is encrypted.  If you still wish to convert it, please mount it in the Finder, then create a new disk image from device.", [[self.convertURL path] lastPathComponent]]];
        [[[self view] window] beginCriticalSheet:self.convertEncryptedWindow completionHandler:^(NSInteger result) {
            //Nothing to handle...
        }];
        return;
    }
    
    //Here's where we put up some conversion options.
    NSString *path = [self.convertURL path];
    NSString *nameExt = [path lastPathComponent];
    NSString *name = [nameExt stringByDeletingPathExtension];
    //Let's show our save panel sheet
    [self resetConvertImageView];
    
    //We're converting a disk image - some options aren't available
    [self.convertFormatPopup setEnabled:NO];
    [self.convertPartitionsPopup setEnabled:NO];
    [self.convertVolumeNameText setEnabled:NO];
    [self.convertVolumeNameText setStringValue:@"Set By Disk Image"];
    //[self.convertVolumeNameText setEditable:NO];
    
    if (!self.imageConvertSave) self.imageConvertSave = [[NSSavePanel alloc] init];
    [self.imageConvertSave setTitle:@"New Disk Image"];
    [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"dmg", nil]];
    [self.imageConvertSave setExtensionHidden:NO];
    [self.imageConvertSave setCanSelectHiddenExtension:YES];
    [self.imageConvertSave setAccessoryView:self.convertImageView];
    [self.imageConvertSave setNameFieldStringValue:name];
    
    [self.imageConvertSave beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        //Handle the shit.
        if (result == NSFileHandlingPanelOKButton) {
            //We clicked Okay
            NSURL *theFile = [self.imageConvertSave URL];
            //Let's run our modal window to kick some ask
            self.diskController = [[CNCreateDiskController alloc] initWithWindowNibName:@"CNCreateDiskController"];
            
            //This is *ONLY* called to load the window nib.
            //Without it, we couldn't get references to the other parts.
            [self.diskController.window setTitle:@""];
            
            
            //We need to build our tasklist
            NSString *name = [NSString stringWithFormat:@"Creating \"%@\"...", [[theFile path] lastPathComponent]];
            
            NSString *encrypt = @"";
            NSString *pass = @"";
            NSString *prefix = @"";
            //NSString *fs = [self.formatTypes objectAtIndex:[self.convertFormatPopup indexOfSelectedItem]];
            NSLog(@"Index of encryptitionPopup: %ld", (long)[self.convertEncryptionPopup indexOfSelectedItem]);
            if ([self.convertEncryptionPopup indexOfSelectedItem]) {
                //NSLog(@"Encryption!!!");
                //Encryption - let's find out if we have a password
                if ([self.passShowButton state]) {
                    //NSLog(@"Show");
                    //We're pulling from the shown text field
                    if (![[self.passOneTextField stringValue] length]) {
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneTextField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.convertEncryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                } else {
                    //NSLog(@"Hidden");
                    if (![[self.passOneSecureField stringValue] length]) {
                        //We're pulling from the hidden text field
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneSecureField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.convertEncryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                }
            }
            
            //NSString *layout = [self.partitionTypes objectAtIndex:[self.convertPartitionsPopup indexOfSelectedItem]];
            NSString *format = [self.convertImageTypes objectAtIndex:[self.convertImageFormatPopup indexOfSelectedItem]];
            
            NSString *formatString = [self.convertImageFormatPopup titleOfSelectedItem];
            NSString *zlib = @"";
            
            //Use admin?
            NSString *useAdmin = @"No";
            if ([_convertAdminPrivs state]) useAdmin = @"Yes";

            if ([formatString isEqualToString:@"zlib-compressed disk image"]) {
                //We have a zlip disk image - let's grab our compression ratio
                zlib = [NSString stringWithFormat:@"-imagekey zlib-level=%i ", (int)[self.convertCompressionSlider doubleValue]];
            } /*else if ([formatString isEqualToString:@"read/write disk image"] || [formatString isEqualToString:@"sparse disk image"] || [formatString isEqualToString:@"sparse bundle disk image"]) {
                //Read/write image
                priv = @"No";
            }*/
            
            
            //Build a string of commands.
            
            NSString *theCommand = @"";
            
            if ([encrypt length]) {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"echo \"%@\\0\" | /usr/bin/hdiutil convert -puppetstrings \"%@\" -ov -format %@ %@-stdinpass -encryption %@ -o \"%@\"", pass, [self.convertURL path], format, zlib, encrypt, [theFile path]]];
            } else {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"/usr/bin/hdiutil convert -puppetstrings \"%@\" -ov -format %@ %@-o \"%@\"",
                                                                  [self.convertURL path], format, zlib, [theFile path]]];
            }
            
            NSString *desc = [NSString stringWithFormat:@"%@, %@", format, encrypt];
            NSString *start  = [NSString stringWithFormat:@"/bin/sh -c %@\n\n", theCommand];
            
            NSArray *args = [NSArray arrayWithObjects:@"-c", theCommand, nil];
            
            //NSLog(@"Running command: /bin/sh -c %@", theCommand);
            
            //Create an sh task so we can send a password in if needed.
            
            NSDictionary *command = [NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", @"Path",
                                     args, @"Args",
                                     name, @"Title",
                                     desc, @"Subtext",
                                     useAdmin, @"Privilege",
                                     @"\nComplete.", @"End Message",
                                     start, @"Start Message",
                                     nil];
            
            [self.diskController setTaskArray:[NSArray arrayWithObjects:command,nil]];
            
            //Run our task, then display the modal window
            [self.diskController startProcess];
            
            //NSString *command = [NSString stringWithFormat:@"hdiutil create -fs \"%@\" -type %@ -layout %@ -size %@ -volname \"%@\" \"%@\"", fs, type, layout, size, volName, [theFile path]];
            
            //Let's let the window handle this now - in the future if there are multiple tasks
            //sent to the modal window - they should complete correctly.
            //Build our privileged task and run it
            
            [[[self view] window] beginSheet:self.diskController.window  completionHandler:^(NSModalResponse returnCode) {
                NSLog(@"Sheet closed");
                
                switch (returnCode) {
                    case NSModalResponseOK:
                        NSLog(@"Done button tapped in Custom Sheet");
                        break;
                    case NSModalResponseCancel:
                        NSLog(@"Cancel button tapped in Custom Sheet");
                        break;
                        
                    default:
                        break;
                }
            }];
            
        }
        
    }];
}

- (void)createImageURL {
    NSString *path = [self.convertURL path];
    NSString *nameExt = [path lastPathComponent];
    NSString *name = [nameExt stringByDeletingPathExtension];
    //Let's show our save panel sheet
    [self resetConvertImageView];
    
    //Set up the volume name field
    [self.convertVolumeNameText setEnabled:YES];
    [self.convertVolumeNameText setStringValue:nameExt];
    
    if (!self.imageConvertSave) self.imageConvertSave = [[NSSavePanel alloc] init];
    [self.imageConvertSave setTitle:@"New Disk Image"];
    [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"dmg", nil]];
    [self.imageConvertSave setExtensionHidden:NO];
    [self.imageConvertSave setCanSelectHiddenExtension:YES];
    [self.imageConvertSave setAccessoryView:self.convertImageView];
    [self.imageConvertSave setNameFieldStringValue:name];
    
    [self.imageConvertSave beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        //Handle the shit.
        if (result == NSFileHandlingPanelOKButton) {
            //We clicked Okay
            NSURL *theFile = [self.imageConvertSave URL];
            //Let's run our modal window to kick some ask
            self.diskController = [[CNCreateDiskController alloc] initWithWindowNibName:@"CNCreateDiskController"];
            
            //This is *ONLY* called to load the window nib.
            //Without it, we couldn't get references to the other parts.
            [self.diskController.window setTitle:@""];
            
            
            //We need to build our tasklist
            NSString *name = [NSString stringWithFormat:@"Creating \"%@\"...", [[theFile path] lastPathComponent]];
            
            NSString *volName = [self.convertVolumeNameText stringValue];

            NSString *encrypt = @"";
            NSString *pass = @"";
            NSString *prefix = @"";
            NSString *fs = [self.formatTypes objectAtIndex:[self.convertFormatPopup indexOfSelectedItem]];
            NSLog(@"Index of encryptitionPopup: %ld", (long)[self.convertEncryptionPopup indexOfSelectedItem]);
            if ([self.convertEncryptionPopup indexOfSelectedItem]) {
                NSLog(@"Encryption!!!");
                //Encryption - let's find out if we have a password
                if ([self.passShowButton state]) {
                    NSLog(@"Show");
                    //We're pulling from the shown text field
                    if (![[self.passOneTextField stringValue] length]) {
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneTextField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.convertEncryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                } else {
                    NSLog(@"Hidden");
                    if (![[self.passOneSecureField stringValue] length]) {
                        //We're pulling from the hidden text field
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneSecureField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.convertEncryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                }
            }
            
            NSString *layout = [self.partitionTypes objectAtIndex:[self.convertPartitionsPopup indexOfSelectedItem]];
            NSString *format = [self.convertImageTypes objectAtIndex:[self.convertImageFormatPopup indexOfSelectedItem]];
            
            NSString *formatString = [self.convertImageFormatPopup titleOfSelectedItem];
            NSString *zlib = @"";
            
            //Use admin?
            NSString *useAdmin = @"No";
            if ([_convertAdminPrivs state]) useAdmin = @"Yes";
            
            if ([formatString isEqualToString:@"zlib-compressed disk image"]) {
                //We have a zlip disk image - let's grab our compression ratio
                zlib = [NSString stringWithFormat:@"-imagekey zlib-level=%i ", (int)[self.convertCompressionSlider doubleValue]];
            } /*else if ([formatString isEqualToString:@"read/write disk image"] || [formatString isEqualToString:@"sparse disk image"] || [formatString isEqualToString:@"sparse bundle disk image"]) {
                //Read/write image
                priv = @"No";
            }*/
            
            //Get volume name
            if (![volName length]) {
                //The name is empty - replace with the original
                //dropped file/folder's name
                volName = nameExt;
            }
            
            //Build a string of commands.
            
            NSString *theCommand = @"";
            
            if ([encrypt length]) {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"echo \"%@\\0\" | /usr/bin/hdiutil create -ov -puppetstrings -volname \"%@\" -srcfolder \"%@\" -fs \"%@\" -format %@ %@-layout %@ -stdinpass -encryption %@ \"%@\"", pass, volName, [self.convertURL path], fs, format, zlib, layout, encrypt, [theFile path]]];
            } else {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"/usr/bin/hdiutil create -ov -puppetstrings -volname \"%@\" -srcfolder \"%@\" -fs \"%@\" -format %@ %@-layout %@ \"%@\"",
                                                                  volName, [self.convertURL path], fs, format, zlib, layout, [theFile path]]];
            }
            
            NSString *desc = [NSString stringWithFormat:@"%@, %@, %@, %@", format, fs, layout, encrypt];
            NSString *start  = [NSString stringWithFormat:@"/bin/sh -c %@\n\n", theCommand];
            
            NSArray *args = [NSArray arrayWithObjects:@"-c", theCommand, nil];
            
            //NSLog(@"Running command: /bin/sh -c %@", theCommand);
            
            //Create an sh task so we can send a password in if needed.
            
            NSDictionary *command = [NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", @"Path",
                                     args, @"Args",
                                     name, @"Title",
                                     desc, @"Subtext",
                                     useAdmin, @"Privilege",
                                     @"\nComplete.", @"End Message",
                                     start, @"Start Message",
                                     nil];
            
            [self.diskController setTaskArray:[NSArray arrayWithObjects:command,nil]];
            
            //Run our task, then display the modal window
            [self.diskController startProcess];
            
            //NSString *command = [NSString stringWithFormat:@"hdiutil create -fs \"%@\" -type %@ -layout %@ -size %@ -volname \"%@\" \"%@\"", fs, type, layout, size, volName, [theFile path]];
            
            //Let's let the window handle this now - in the future if there are multiple tasks
            //sent to the modal window - they should complete correctly.
            //Build our privileged task and run it
            
            [[[self view] window] beginSheet:self.diskController.window  completionHandler:^(NSModalResponse returnCode) {
                NSLog(@"Sheet closed");
                
                switch (returnCode) {
                    case NSModalResponseOK:
                        NSLog(@"Done button tapped in Custom Sheet");
                        break;
                    case NSModalResponseCancel:
                        NSLog(@"Cancel button tapped in Custom Sheet");
                        break;
                        
                    default:
                        break;
                }
            }];
            
        }
        
    }];
}

- (IBAction)encryptedImageCancel:(id)sender {
    [[[self view] window] endSheet:self.convertEncryptedWindow];
}

- (IBAction)encryptedImageCreate:(id)sender {
    [[[self view] window] endSheet:self.convertEncryptedWindow];
    if (self.convertURL) [self createImageURL];
}

- (IBAction)chooseConvert:(id)sender {
    //We want to convert the image we selected
    [[[self view] window] endSheet:self.convertInsteadWindow returnCode:NSModalResponseOK];
    if (self.convertURL) [self convertImageURL];
    //[self isEncrypted:self.convertURL];
}

- (IBAction)chooseCreate:(id)sender {
    //We want to create a new image containing the selected file
    [[[self view] window] endSheet:self.convertInsteadWindow returnCode:NSModalResponseOK];
    if (self.convertURL) [self createImageURL];
}

- (IBAction)chooseCancel:(id)sender {
    //User canceled
    [[[self view] window] endSheet:self.convertInsteadWindow returnCode:NSModalResponseCancel];
}

- (IBAction)diskImageDisk:(id)sender {
    //Let's show our save panel sheet
    [self resetConvertImageView];
    
    //We're converting a disk image - some options aren't available
    [self.convertFormatPopup setEnabled:NO];
    [self.convertPartitionsPopup setEnabled:NO];
    [self.convertVolumeNameText setEnabled:NO];
    [self.convertVolumeNameText setStringValue:@"Set by Disk"];
    
    if (!self.imageConvertSave) self.imageConvertSave = [[NSSavePanel alloc] init];
    [self.imageConvertSave setTitle:@"New Disk Image"];
    [self.imageConvertSave setAllowedFileTypes:[NSArray arrayWithObjects:@"dmg", nil]];
    [self.imageConvertSave setExtensionHidden:NO];
    [self.imageConvertSave setCanSelectHiddenExtension:YES];
    [self.imageConvertSave setAccessoryView:self.convertImageView];
    [self.imageConvertSave setNameFieldStringValue:self.selectedDiskName];
    
    [self.imageConvertSave beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result) {
        //Handle the shit.
        if (result == NSFileHandlingPanelOKButton) {
            //We clicked Okay
            NSURL *theFile = [self.imageConvertSave URL];
            //Let's run our modal window to kick some ask
            self.diskController = [[CNCreateDiskController alloc] initWithWindowNibName:@"CNCreateDiskController"];
            
            //This is *ONLY* called to load the window nib.
            //Without it, we couldn't get references to the other parts.
            [self.diskController.window setTitle:@""];
            
            
            //We need to build our tasklist
            NSString *name = [NSString stringWithFormat:@"Creating \"%@\"...", [[theFile path] lastPathComponent]];
            
            NSString *encrypt = @"";
            NSString *pass = @"";
            NSString *prefix = @"";
            if ([self.convertEncryptionPopup indexOfSelectedItem]) {
                //Encryption - let's find out if we have a password
                if ([self.passShowButton state]) {
                    //We're pulling from the shown text field
                    if (![[self.passOneTextField stringValue] length]) {
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneTextField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.convertEncryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                } else {
                    //NSLog(@"Hidden");
                    if (![[self.passOneSecureField stringValue] length]) {
                        //We're pulling from the hidden text field
                        //0 length string = no password = no encryption
                        encrypt = @"";
                    } else {
                        pass = [self.passOneSecureField stringValue];
                        encrypt = [self.encryptionTypes objectAtIndex:[self.convertEncryptionPopup indexOfSelectedItem]];
                        prefix = [NSString stringWithFormat:@"echo \"%@\" | ", pass];
                    }
                }
            }
            
            //NSString *layout = [self.partitionTypes objectAtIndex:[self.convertPartitionsPopup indexOfSelectedItem]];
            NSString *format = [self.convertImageTypes objectAtIndex:[self.convertImageFormatPopup indexOfSelectedItem]];
            
            NSString *formatString = [self.convertImageFormatPopup titleOfSelectedItem];
            NSString *zlib = @"";
            
            //Are we defaulting to admin privs?
            NSString *useAdmin = @"No";
            if ([_convertAdminPrivs state]) useAdmin = @"Yes";
            
            if ([formatString isEqualToString:@"zlib-compressed disk image"]) {
                //We have a zlip disk image - let's grab our compression ratio
                zlib = [NSString stringWithFormat:@"-imagekey zlib-level=%i ", (int)[self.convertCompressionSlider doubleValue]];
            } /*else if ([formatString isEqualToString:@"read/write disk image"] || [formatString isEqualToString:@"sparse disk image"] || [formatString isEqualToString:@"sparse bundle disk image"]) {
                //Read/write image
                priv = @"No";
            }*/
            
            
            //Build a string of commands.
            
            NSString *theCommand = @"";
            
            if ([encrypt length]) {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"echo \"%@\\0\" | /usr/bin/hdiutil create -puppetstrings -srcdevice %@ -ov -format %@ %@-stdinpass -encryption %@\"%@\"", pass, [self.currentDisk BSDName], format, zlib, encrypt, [theFile path]]];
            } else {
                theCommand = [theCommand stringByAppendingString:[NSString stringWithFormat:@"/usr/bin/hdiutil create -puppetstrings -srcdevice %@ -ov -format %@ %@\"%@\"",
                                                                  [self.currentDisk BSDName], format, zlib, [theFile path]]];
            }
            
            NSString *desc = [NSString stringWithFormat:@"%@, %@", format, encrypt];
            NSString *start  = [NSString stringWithFormat:@"/bin/sh -c %@\n\n", theCommand];
            
            NSArray *args = [NSArray arrayWithObjects:@"-c", theCommand, nil];
            
            //NSLog(@"Running command: /bin/sh -c %@", theCommand);
            
            //Create an sh task so we can send a password in if needed.
            
            NSDictionary *command = [NSDictionary dictionaryWithObjectsAndKeys:@"/bin/sh", @"Path",
                                     args, @"Args",
                                     name, @"Title",
                                     desc, @"Subtext",
                                     useAdmin, @"Privilege",
                                     @"\nComplete.", @"End Message",
                                     start, @"Start Message",
                                     nil];
            
            [self.diskController setTaskArray:[NSArray arrayWithObjects:command,nil]];
            
            //Run our task, then display the modal window
            [self.diskController startProcess];
            
            //NSString *command = [NSString stringWithFormat:@"hdiutil create -fs \"%@\" -type %@ -layout %@ -size %@ -volname \"%@\" \"%@\"", fs, type, layout, size, volName, [theFile path]];
            
            //Let's let the window handle this now - in the future if there are multiple tasks
            //sent to the modal window - they should complete correctly.
            //Build our privileged task and run it
            
            [[[self view] window] beginSheet:self.diskController.window  completionHandler:^(NSModalResponse returnCode) {
                NSLog(@"Sheet closed");
                
                switch (returnCode) {
                    case NSModalResponseOK:
                        NSLog(@"Done button tapped in Custom Sheet");
                        break;
                    case NSModalResponseCancel:
                        NSLog(@"Cancel button tapped in Custom Sheet");
                        break;
                        
                    default:
                        break;
                }
            }];
            
        }
        
    }];
}

#pragma mark - Outline View Delegate Methods


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (item == nil) {
        // Root
        return [diskArray objectAtIndex:index];
    }
    
    if ([item isKindOfClass:[Disk class]]) {
        Disk *disk = item;
        return [disk.children objectAtIndex:index];
    }
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if ([item isKindOfClass:[NSArray class]]) {
        return YES;
    }
    if ([item isKindOfClass:[Disk class]]) {
        Disk *disk = item;
        if ([disk.children count] > 0) {
            return YES;
        }
    }
    return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        // Root
        return [diskArray count];
    }
    
    /*if ([item isKindOfClass:[Disk class]] && [item hasChildren]) {
        return [[item getChildren] count];
    }*/
    
    if ([item isKindOfClass:[Disk class]]) {
        Disk *disk = item;
        return [disk.children count];
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn byItem:(nullable id)item {
    
    if ([item isKindOfClass:[Disk class]]) {
        
        // Setup some variables
        
        Disk *disk = item;
        NSColor *color = [NSColor blackColor];
        NSString *diskName = @"";
        
        // Color accordingly:
        // Boot drive = Blue
        // Whole disk = Black
        // Parition   = Dark Gray
        // Selected   = White
        
        id selectedItem = [outlineView itemAtRow:[outlineView selectedRow]];
        
        if (item == selectedItem) {
            color = [NSColor whiteColor];
        } else if ([disk isBootDisk] || [disk isBootVolume]){
            color = [NSColor blueColor];
        } else if ([disk isMounted]) {
            color = [NSColor blackColor];
        } else if ([disk isWholeDisk]) {
            BOOL anyMounted = NO;
            for (Disk *child in [disk children]) {
                // Find out if all disks are unmounted
                if ([child isMounted]) anyMounted = YES;
            }
            if (!anyMounted) color = [NSColor darkGrayColor];
        } else {
            color = [NSColor darkGrayColor];
        }
        
        // Get a name for our disk
        // If whole disk - mediaName
        // if not, volumeName
        
        if ([disk volumeName]) {
            diskName = [disk volumeName];
        } else if ([disk mediaName]) {
            diskName = [disk mediaName];
        }
        
        // Setup our string and return it
        
        NSDictionary *attrs = @{ NSForegroundColorAttributeName : color };
        return [[NSAttributedString alloc] initWithString:diskName attributes:attrs];
    }
    
    return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item isKindOfClass:[Disk class]]) {
        Disk *currentDisk = item;
        if ((tableColumn == nil) || [[tableColumn identifier] isEqualToString:COLUMNID_NAME]) {
            NSImage *tempImage = [currentDisk.icon copy];
            
            NSImage *diskImage = [self imageResize:tempImage newSize:imageSize];
            // We know that the cell at this column is our image and text cell, so grab it
            AAPLImageAndTextCell *imageAndTextCell = (AAPLImageAndTextCell *)cell;
            // Set the image here since the value returned from outlineView:objectValueForTableColumn:... didn't specify the image part...
            imageAndTextCell.myImage = diskImage;
            if ([currentDisk isWholeDisk]) {
                imageAndTextCell.opacity = 1;
            } else {
                if ([currentDisk isMounted]) {
                    imageAndTextCell.opacity = 0.9;
                } else {
                    imageAndTextCell.opacity = 0.4;
                }
            }
        }
    // For all the other columns, we don't do anything.
    }
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    return imageSize.height + IMAGE_PAD;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
   shouldSelectItem:(id)item {
    return !_runningTask;
}

#pragma mark - Resize NSImage

- (NSImage *)imageResize:(NSImage*)anImage newSize:(NSSize)newSize {
    NSImage *sourceImage = anImage;
    //[sourceImage setScalesWhenResized:YES];
    
    // Report an error if the source isn't a valid image
    if (![sourceImage isValid]){
        NSLog(@"Invalid Image");
    } else {
        NSImage *smallImage = [[NSImage alloc] initWithSize: newSize];
        [smallImage lockFocus];
        [sourceImage setSize: newSize];
        [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
        [sourceImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositeCopy fraction:1.0];
        [smallImage unlockFocus];
        return smallImage;
    }
    return nil;
}


#pragma mark - Notification Methods

- (void)diskAppeared:(NSNotification *)notification {
    //Disk *disk = notification.object;
    
    //NSLog(@"Volume Path: %@", disk.volumePath);
    //NSLog(@"Disk Appeared: %@", disk.BSDName);
    //NSLog(@"Description: %@", disk.description);

    //NSLog(@"Disks Count - %lu", (unsigned long)[allDisks count]);
    //NSLog(@"Disks:\n%@", diskArray);
    
    [_diskView reloadData];
    [self respondToSelectedItem:_diskView];
}

- (void)diskDisappeared:(NSNotification *)notification {
    Disk *disk = notification.object;
    
   // NSLog(@"Disk Disappeared - %@", disk.BSDName);
    
    [disk disappeared];
    
    [_diskView reloadData];
    [self respondToSelectedItem:_diskView];
}

- (void)volumeMountNotification:(NSNotification *) notification {
    /*Disk *disk = [Disk getDiskForUserInfo:notification.userInfo];
    
    if (disk) {
        //NSLog(@"Disk: '%@' mounted at '%@'", disk.BSDName, disk.volumePath);
    }*/
    
    [_diskView reloadData];
    [self respondToSelectedItem:_diskView];
    
}

- (void)volumeUnmountNotification:(NSNotification *) notification {
    /*Disk *disk = [Disk getDiskForUserInfo:notification.userInfo];
    
    if (disk) {
        //NSLog(@"Disk: '%@' unmounted from '%@'", disk.BSDName, disk.volumePath);
    }*/
    
    [_diskView reloadData];
    [self respondToSelectedItem:_diskView];
}

- (void)_childDidAttemptUnmountBeforeEject:(NSNotification *) notification {
    Disk *disk = notification.object;
    
    //Check if disk is whole disk or not.
    Disk *parent = disk.isWholeDisk ? disk : disk.parent;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"DADiskDidAttemptUnmountNotification" object:disk];
    
    //confirm child unmounted...
    
    if (disk.isMounted) {
        // Unmount of child failed.
        [self appendOutput:[NSString stringWithFormat:@"Failed to unmount disk: %@\n", parent.BSDName]];
        [self appendOutput:[NSString stringWithFormat:@"Canceled due to mounted child: %@\n", disk.BSDName]];
        
        //NSMutableDictionary *info = (NSMutableDictionary *)[notification userInfo];
        
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"DADiskDidAttemptEjectNotification" object:disk userInfo:info];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DADiskDidAttemptEjectNotification" object:disk userInfo:nil];
    }
    
    // Child from notification is unmounted, check for remaining children to unmount
    
    for (Disk *child in parent.children) {
        if (child.isMounted)
            return;			// Still waiting for child
    }
    
    // Need to test if parent is ejectable because we enable "Eject" for a disk
    // that has children that can be unmounted (ala Disk Utility)
    
    if (parent.isEjectable)
        [parent eject];
}

#pragma mark - Private Methods

- (void)registerSession {
    // App Level Notification
    NSNotificationCenter *acenter = [NSNotificationCenter defaultCenter];
    
    [acenter addObserver:self selector:@selector(diskAppeared:) name:@"diskAppearedNotification" object:nil];
    [acenter addObserver:self selector:@selector(diskDisappeared:) name:@"diskDisappearedNotification" object:nil];
    
    // Workspace Level Notification
    NSNotificationCenter *wcenter = [[NSWorkspace sharedWorkspace] notificationCenter];
    
    [wcenter addObserver:self selector:@selector(volumeMountNotification:) name:NSWorkspaceDidMountNotification object:nil];
    [wcenter addObserver:self selector:@selector(volumeUnmountNotification:) name:NSWorkspaceDidUnmountNotification object:nil];
}

- (void)unregisterSession {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (Boolean)isEncrypted:(NSURL *)url {
    //This little method's goal is to check whether or not
    //a passed disk image is encrypted.
    if (!url) return NO;
    
    NSTask * encrypted = [[NSTask alloc] init];
    [encrypted setLaunchPath:@"/usr/bin/hdiutil"];
    //[encrypted setCurrentDirectoryPath:@"/"];
    [encrypted setArguments:[NSArray arrayWithObjects:@"isencrypted", [url path], nil]];
    
    NSPipe * outP = [NSPipe pipe];
    [encrypted setStandardOutput:outP];
    
    [encrypted launch];
    [encrypted waitUntilExit];
    
    NSFileHandle * read = [outP fileHandleForReading];
    NSData * dataRead = [read readDataToEndOfFile];
    NSString * stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
    if ([stringRead hasPrefix:@"encrypted: YES"]) {
        return YES;
    }
    
    return NO;
}

- (void)launchNextTask {
    if (!_runningTask) {
        //We're not doing anything yet - so let's start a task
        if ([_tasksToRun count] > 0) {
            //There indeed ARE tasks to run :D
            NSString *path = [[_tasksToRun objectAtIndex:0] objectForKey:@"Path"];
            NSArray *args = [[_tasksToRun objectAtIndex:0] objectForKey:@"Args"];
            [self launchPTWithPath:path arguments:args];
        }
        //No tasks - we're done.
    }
    //Currently running tasks - nothing to do yet.
}

- (void)launchPTWithPath:(NSString *)path arguments:(NSArray *)args {
    //Build our privileged task
    STPrivilegedTask *privilegedTask = [[STPrivilegedTask alloc] init];
    [privilegedTask setLaunchPath:path];
    [privilegedTask setArguments:args];
    
    //Launch our privileged task
    _runningTask=YES;
    [_taskRunning setHidden:NO];
    [_taskRunning startAnimation:nil];
    [self disableButtons];
    
    OSStatus err = [privilegedTask launch];
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled) {
            NSLog(@"User cancelled");
            [self appendOutput:@"\nUser Canceled.\n\n"];
            [_taskRunning setHidden:YES];
            [_taskRunning stopAnimation:nil];
            [self respondToSelectedItem:_diskView];
            _runningTask = NO;
            
            //Remove all tasks since we failed to authent.
            if ([_tasksToRun count] > 0) {
                [_tasksToRun removeAllObjects];
            }
        } else {
            NSLog(@"Something went wrong");
            [self appendOutput:@"\nSomething Went Wrong :(\n\n"];
            [_taskRunning setHidden:YES];
            [_taskRunning stopAnimation:nil];
            [self respondToSelectedItem:_diskView];
            _runningTask = NO;
            
            //Remove current task due to error - and move to the next.
            if ([_tasksToRun count] > 0) {
                [_tasksToRun removeObjectAtIndex:0];
                [self launchNextTask];
            }
        }
    } else {
        NSLog(@"%@ successfully launched", path);
        
        //Check for a launch message...
        if ([[_tasksToRun objectAtIndex:0] objectForKey:@"Start Message"]) {
            [self appendOutput:[[_tasksToRun objectAtIndex:0] objectForKey:@"Start Message"]];
        }
    
        //Get output in background
        NSFileHandle *readHandle = [privilegedTask outputFileHandle];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getOutputData:) name:NSFileHandleReadCompletionNotification object:readHandle];
        [readHandle readInBackgroundAndNotify];
    }
}

- (void)getOutputData:(NSNotification *)aNotification {
    //get data from notification
    NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    //make sure there's actual data
    if ([data length]) {
        // do something with the data
        
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (![output hasPrefix:@"Repairing the partition map might erase"]) {
            [self appendOutput:output];
        }
        // go read more data in the background
        [[aNotification object] readInBackgroundAndNotify];
    } else {
        // do something else
    }
}

- (void)appendOutput:(NSString *)output {
    NSString *outputWithNewLine = [output stringByAppendingString:@""];
    
    //Smart Scrolling
    BOOL scroll = (NSMaxY(_outputText.visibleRect) == NSMaxY(_outputText.bounds));
    
    //Append string to textview
    [_outputText.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:outputWithNewLine]];
    
    if (scroll) [_outputText scrollRangeToVisible:NSMakeRange(_outputText.string.length, 0)];
}

- (void)privilegedTaskFinished:(NSNotification *)aNotification {
    // add 3 blank lines of output and end task.
    if ([[_tasksToRun objectAtIndex:0] objectForKey:@"End Message"]) {
        [self appendOutput:[[_tasksToRun objectAtIndex:0] objectForKey:@"End Message"]];
    }
    [_taskRunning setHidden:YES];
    [_taskRunning stopAnimation:nil];
    [self respondToSelectedItem:_diskView];
    _runningTask = NO;
    
    //Remove the finished task and
    //try to launch the next task if it exists
    if ([_tasksToRun count] > 0) {
        [_tasksToRun removeObjectAtIndex:0];
        [self launchNextTask];
    }
}

- (void)clearMainWindow {
    // Clear the text fields in the window
    [_mountPointText setStringValue:@""];
    [_capacityText setStringValue:@""];
    [_usedText setStringValue:@""];
    [_uuidText setStringValue:@""];
    [_typeText setStringValue:@""];
    [_availableText setStringValue:@""];
    [_deviceText setStringValue:@""];
    [_diskNameField setStringValue:@""];
    [_diskInfoField setStringValue:@""];
    [_diskImageField setImage:nil];
    [_diskSize setMaxValue:1];
    [_diskSize setDoubleValue:0];
    [_diskSize incrementBy:1];
    
    //No disks selected - can't make disk image from source
    [_diskImage setTitle:@"Select disk to create image from source..."];
    [_diskImage setEnabled:NO];
}

- (void)disableButtons {
    [_repairPermissionsButton setEnabled:NO];
    [_rebuildKextCacheButton setEnabled:NO];
    [_repairDiskButton setEnabled:NO];
    [_verifyDiskButton setEnabled:NO];
    //[_ejectButton setEnabled:NO];
    [_mountButton setEnabled:NO];
    [_eraseButton setEnabled:NO];
    [_partitionButton setEnabled:NO];
    [_diskImageButton setEnabled:NO];
}

- (NSPoint) convertPointToScreen:(NSPoint)point
{
    NSRect convertRect = [[[self view] window] convertRectToScreen:NSMakeRect(point.x, point.y, 0.0, 0.0)];
    return NSMakePoint(convertRect.origin.x, convertRect.origin.y);
}

- (void)sizeTextFieldBeep {
    NSBeep();
    [_sizeTextField setStringValue:@"10"];
    [_sizeTextPopup selectItemWithTitle:@"MB"];
}

- (void)resetNewBlankImageView {
    [_nameTextField setStringValue:@"Untitled"];
    [_sizePopup selectItemAtIndex:0];
    [_sizeTextField setStringValue:@"100"];
    [_sizeTextPopup selectItemAtIndex:0];
    [_formatPopup selectItemAtIndex:0];
    [_encryptionPopup selectItemAtIndex:0];
//  [_encryptionShowButton setState:0];
//  [_encryptionShowButton setEnabled:NO];
//  [_encryptionTextField setStringValue:@""];
//  [_encryptionTextField setHidden:YES];
//  [_encryptionTextField setEnabled:NO];
//  [_encryptionSecureField setStringValue:@""];
//  [_encryptionSecureField setHidden:NO];
//  [_encryptionSecureField setEnabled:NO];
    [_partitionsPopup selectItemAtIndex:2];
    [_imageFormatPopup selectItemAtIndex:2];
    [_sizePopup setHidden:YES];
    [_sizeTextField setHidden:NO];
    [_sizeTextPopup setHidden:NO];
    //Needs a prefs check
    [_blankAdminPrivs setState:0];
}

- (void)resetConvertImageView {
    /*@property (assign) IBOutlet NSView *convertImageView;
     @property (assign) IBOutlet NSPopUpButton *convertFormatPopup;
     @property (assign) IBOutlet NSPopUpButton *convertEncryptionPopup;
     @property (assign) IBOutlet NSPopUpButton *convertPartitionsPopup;
     @property (assign) IBOutlet NSPopUpButton *convertImageFormatPopup;
     @property (assign) IBOutlet NSSlider *convertCompressionSlider;
     @property (assign) IBOutlet NSTextField *convertCompressionText;*/
    [self.convertFormatPopup setEnabled:YES];
    [self.convertFormatPopup selectItemAtIndex:0];
    [self.convertEncryptionPopup selectItemAtIndex:0];
    [self.convertPartitionsPopup setEnabled:YES];
    [self.convertPartitionsPopup selectItemAtIndex:2];
    [self.convertImageFormatPopup selectItemAtIndex:3];
    [self.convertCompressionSlider setFloatValue:9.0];
    [self.convertCompressionSlider setEnabled:YES];
    [self compressionLevelChanged:self.convertCompressionSlider];
    [self.convertVolumeNameText setEnabled:NO];
    [self.convertVolumeNameText setStringValue:@"Set By Disk Image"];
    //[self.convertVolumeNameText setEditable:NO];
    //[self.convertRemoveExtButton setState:1];
    //[self.convertRemoveExtButton setEnabled:YES];
    
    //Needs a prefs check
    [self.convertAdminPrivs setState:0];
    
}

- (void)resetPassWindow {
    [self.passNoBlank setHidden:YES];
    [self.passNoBlank setStringValue:@"Password cannot be blank"];
    [self.passOneTextField setStringValue:@""];
    [self.passTwoTextField setStringValue:@""];
    [self.passOneSecureField setStringValue:@""];
    [self.passTwoSecureField setStringValue:@""];
    [self.passShowButton setState:0];
    [self.passOneTextField setHidden:YES];
    [self.passOneTextField setHidden:YES];
    [self.passOneSecureField setHidden:NO];
    [self.passTwoSecureField setHidden:NO];
}

@end
