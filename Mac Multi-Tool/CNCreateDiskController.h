//
//  CNCreateDiskController.h
//  Mac Multi-Tool
//
//  Created by Kristopher Scruggs on 5/19/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CNCreateDiskController : NSWindowController

@property (assign) IBOutlet NSImageView *image;
@property (assign) IBOutlet NSTextField *name;
@property (assign) IBOutlet NSTextField *desc;
@property (assign) IBOutlet NSTextView *detail;
@property (assign) IBOutlet NSButton *doneButton;
@property (assign) IBOutlet NSProgressIndicator *progress;

@end
