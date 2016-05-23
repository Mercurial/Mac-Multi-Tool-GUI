//
//  CNModalPassController.h
//  Mac Multi-Tool
//
//  Created by Kristopher Scruggs on 5/22/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CNModalPassController : NSWindowController

@property (assign) IBOutlet NSTextField *passOne;
@property (assign) IBOutlet NSTextField *passTwo;
@property (assign) IBOutlet NSTextField *blankText;

@property (assign) IBOutlet NSButton *cancelButton;
@property (assign) IBOutlet NSButton *chooseButton;

@end
