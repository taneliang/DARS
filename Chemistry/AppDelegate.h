//
//  AppDelegate.h
//  DARS
//
//  Created by E-Liang Tan on 14/4/12.
//  Copyright (c) 2012 E-Liang Tan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DARS.h"
#import "DARSDatabase.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, DARSDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (strong) NSSpeechSynthesizer *speechSynthesizer;
@property (strong) DARS *DARS;
@property (strong) IBOutlet NSArrayController *conversation;

//@property (weak) IBOutlet NSScrollView *textViewContainer;
@property (unsafe_unretained) IBOutlet NSTextView *textView;
//@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *textField;
@property (strong) NSMutableParagraphStyle *paragraphStyle;
- (IBAction)enterMessage:(id)sender;

@end
