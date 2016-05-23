//
//  CNCreateDiskController.m
//  Mac Multi-Tool
//
//  Created by Kristopher Scruggs on 5/19/16.
//  Copyright © 2016 Corporate Newt Software. All rights reserved.
//

#import "CNCreateDiskController.h"
#import "STPrivilegedTask.h"

@interface CNCreateDiskController ()

@end

/*
 
 We're looking for an array of Dictionaries organized as such:
 
 Key           : Type     : Explanation
 ----------------------------------------------------------------
 Path          : NSString : Path to task to run
 Args          : NSArray  : Array of NSString arguments
 Start Message : NSString : Message to display at start of task
 End Message   : NSString : Message to display at end of task
 Title         : NSString : Outline of what we're doing (ex. "Creating Image \"Untitled\"...")
 Subtext       : NSString : More specific than title (ex. "Read/Write, GUID Partition Table, 100MB, \"Untitled.dmg\"")
 Image         : NSImage  : Icon to display - uses application icon if nil
 
*/

@implementation CNCreateDiskController

- (void)windowDidLoad {
    [super windowDidLoad];
    _runningTask = NO;
}

- (IBAction)didTapDoneButton:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

#pragma mark - Task Functions

- (void)setTaskArray:(NSArray *)tList {
    if (tList) {
        self.taskList = [NSMutableArray arrayWithArray:tList];
    }
}

- (void)startProcess {
    if (_taskList) {
        //We have a valid list - let's iterate through it.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(privilegedTaskFinished:) name:@"STPrivilegedModalTaskDidTerminateNotification" object:nil];
        [self launchNextTask];
    } else {
        
        //If we don't - we enabled our done button to close the window.
        [_doneButton setEnabled:YES];
        
    }
}

#pragma mark - Output Data

- (void)getOutputData:(NSNotification *)aNotification {
    //get data from notification
    NSData *data = [[aNotification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    
    //make sure there's actual data
    if ([data length]) {
        // do something with the data
        
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if ([output hasPrefix:@"PERCENT:"]) {
            NSArray *percArray = [output componentsSeparatedByString:@":"];
            float prog = [[percArray objectAtIndex:1] floatValue];
            if (prog == -1) {
                [self.progress setIndeterminate:YES];
                [self.progress startAnimation:nil];
            } else {
                [self.progress setIndeterminate:NO];
                [self.progress setMaxValue:100];
                [self.progress setDoubleValue:prog];
            }
        } else {
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
    BOOL scroll = (NSMaxY(_detail.visibleRect) == NSMaxY(_detail.bounds));
    
    //Append string to textview
    [_detail.textStorage appendAttributedString:[[NSAttributedString alloc] initWithString:outputWithNewLine]];
    
    if (scroll) [_detail scrollRangeToVisible:NSMakeRange(_detail.string.length, 0)];
}

- (void)privilegedTaskFinished:(NSNotification *)aNotification {
    if ([[_taskList objectAtIndex:0] objectForKey:@"End Message"]) {
        [self appendOutput:[[_taskList objectAtIndex:0] objectForKey:@"End Message"]];
    }
    _runningTask = NO;
    [self.progress setIndeterminate:NO];
    [self.progress setMaxValue:100];
    [self.progress setDoubleValue:100];
    [_doneButton setEnabled:YES];
    
    //Remove the finished task and
    //try to launch the next task if it exists
    if ([_taskList count] > 0) {
        [_taskList removeObjectAtIndex:0];
        [self launchNextTask];
    }
}

#pragma mark - Private Methods

- (void)launchNextTask {
    if (!_runningTask) {
        //We're not doing anything yet - so let's start a task
        if ([_taskList count] > 0) {
            //There indeed ARE tasks to run :D
            NSString *path = [[_taskList objectAtIndex:0] objectForKey:@"Path"];
            NSArray *args = [[_taskList objectAtIndex:0] objectForKey:@"Args"];
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
    [privilegedTask setNotificationToPost:@"STPrivilegedModalTaskDidTerminateNotification"];
    
    //Launch our privileged task
    _runningTask=YES;
    [self.progress setIndeterminate:YES];
    [self.progress startAnimation:nil];
    [_doneButton setEnabled:NO];
    
    OSStatus err = [privilegedTask launch];
    if (err != errAuthorizationSuccess) {
        if (err == errAuthorizationCanceled) {
            [self appendOutput:@"\nUser Canceled.\n\n"];
            [_doneButton setEnabled:YES];
            [self.progress setIndeterminate:NO];
            [self.progress setMaxValue:100];
            [self.progress setDoubleValue:100];
            _runningTask = NO;
            
            //Remove all tasks since we failed to authent.
            if ([_taskList count] > 0) {
                [_taskList removeAllObjects];
            }
        } else {
            [self appendOutput:@"\nSomething Went Wrong :(\n\n"];
            [_doneButton setEnabled:YES];
            [self.progress setIndeterminate:NO];
            [self.progress setMaxValue:100];
            [self.progress setDoubleValue:100];
            _runningTask = NO;
            
            //Remove current task due to error - and move to the next.
            if ([_taskList count] > 0) {
                [_taskList removeObjectAtIndex:0];
                [self launchNextTask];
            }
        }
    } else {
        NSLog(@"%@ successfully launched", path);
        
        //Check for a launch message...
        if ([[_taskList objectAtIndex:0] objectForKey:@"Start Message"]) {
            [self appendOutput:[[_taskList objectAtIndex:0] objectForKey:@"Start Message"]];
        }
        //Grab specific title - otherwise replace with task path
        if ([[_taskList objectAtIndex:0] objectForKey:@"Title"]) {
            [self.name setStringValue:[[_taskList objectAtIndex:0] objectForKey:@"Title"]];
        } else {
            [self.name setStringValue:[NSString stringWithFormat:@"Running task \"%@\"...", [[_taskList objectAtIndex:0] objectForKey:@"Path"]]];
        }
        //Grab subtext (description) if available
        if ([[_taskList objectAtIndex:0] objectForKey:@"Subtext"]) {
            [self.desc setStringValue:[[_taskList objectAtIndex:0] objectForKey:@"Subtext"]];
        } else {
            [self.desc setStringValue:@""];
        }
        
        //Get output in background
        NSFileHandle *readHandle = [privilegedTask outputFileHandle];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getOutputData:) name:NSFileHandleReadCompletionNotification object:readHandle];
        [readHandle readInBackgroundAndNotify];
    }
}

@end
