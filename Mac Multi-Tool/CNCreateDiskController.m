//
//  CNCreateDiskController.m
//  Mac Multi-Tool
//
//  Created by Kristopher Scruggs on 5/19/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import "CNCreateDiskController.h"

@interface CNCreateDiskController ()

@end

@implementation CNCreateDiskController

- (void)windowDidLoad {
    [super windowDidLoad];
    // Do view setup here.
    //NSLog(@"This is where I will add code.");
}

- (IBAction)didTapDoneButton:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

@end
