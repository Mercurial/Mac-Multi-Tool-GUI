//
//  CNModalPassController.m
//  Mac Multi-Tool
//
//  Created by Kristopher Scruggs on 5/22/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import "CNModalPassController.h"

@interface CNModalPassController ()

@end

@implementation CNModalPassController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)didTapChooseButton:(id)sender {
    [NSApp endSheet:self.window];
    //[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)didTapCancelButton:(id)sender {
    [NSApp endSheet:self.window];
    //[self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end
