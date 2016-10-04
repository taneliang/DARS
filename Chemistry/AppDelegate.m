//
//  AppDelegate.m
//  DARS
//
//  Created by E-Liang Tan on 14/4/12.
//  Copyright (c) 2012 E-Liang Tan. All rights reserved.
//

#import "AppDelegate.h"

@interface DARSMessage : NSObject

@property (nonatomic) NSString *message;
@property (nonatomic) NSString *sender;

@end

@implementation DARSMessage

@synthesize message;
@synthesize sender;

@end

@implementation AppDelegate

@synthesize window = _window;
@synthesize speechSynthesizer = _speechSynthesizer;
@synthesize DARS = _lipup;
@synthesize conversation = _conversation;

//@synthesize textViewContainer = _textViewContainer;
@synthesize textView = _textView;
//@synthesize tableView = _tableView;
@synthesize textField = _textField;
@synthesize paragraphStyle = _paragraphStyle;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
	self.speechSynthesizer = [[NSSpeechSynthesizer alloc] init];
	self.DARS = [[DARS alloc] initWithVocabularyFile:[[NSBundle mainBundle] pathForResource:@"default_lipup" ofType:@"js"]];
	self.DARS.delegate = self;
	[self.DARS.brain resetVocabulary:[[NSBundle mainBundle] pathForResource:@"vocabulary" ofType:@"txt"]];
	self.textField.stringValue = [NSString stringWithFormat:@"attach database (%@) (%@)", [[NSBundle mainBundle] pathForResource:@"self" ofType:@"db"], [[NSBundle mainBundle] pathForResource:@"self_db" ofType:@"js"]];
	self.paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	[self.paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
	[self.paragraphStyle setParagraphSpacing:3];
}

- (IBAction)enterMessage:(id)sender {
	NSString *enteredText = self.textField.stringValue;
	self.textField.stringValue = @"";
	DARSMessage *moiMessage = [[DARSMessage alloc] init];
	moiMessage.message = enteredText;
	moiMessage.sender = @"Moi";
	NSMutableAttributedString *moiMessageAttributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - %@\n", moiMessage.sender, moiMessage.message]];
	[moiMessageAttributedString setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:11], NSFontAttributeName, self.paragraphStyle, NSParagraphStyleAttributeName, nil] range:[[moiMessageAttributedString string] rangeOfString:moiMessage.sender]];
	[[self.textView textStorage] appendAttributedString:moiMessageAttributedString];
	[self.DARS getReplyFromInput:enteredText];
	
//	[self.textViewContainer scrollRectToVisible:NSMakeRect(0, self.textViewContainer.contentSize.height, 0, 0)];
//	
//	NSPoint newScrollOrigin;
//    if ([[self.textViewContainer documentView] isFlipped]) {
//        newScrollOrigin=NSMakePoint(0.0, NSMaxY([[self.textViewContainer documentView] frame])-NSHeight([[self.textViewContainer contentView] bounds]));
//    } else {
//        newScrollOrigin=NSMakePoint(0.0,0.0);
//    }
//	
//    [[self.textViewContainer documentView] scrollPoint:newScrollOrigin];
}

- (void)DARS:(DARS *)dars didComputeReply:(NSString *)reply fromInput:(NSString *)input {	
	[self.speechSynthesizer startSpeakingString:reply];
	DARSMessage *systemeMessage = [[DARSMessage alloc] init];
	systemeMessage.message = reply;
	systemeMessage.sender = @"Système";
	NSMutableAttributedString *systemeMessageAttributedString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ - %@\n", systemeMessage.sender, systemeMessage.message]];
	[systemeMessageAttributedString setAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSFont boldSystemFontOfSize:11], NSFontAttributeName, self.paragraphStyle, NSParagraphStyleAttributeName, nil] range:[[systemeMessageAttributedString string] rangeOfString:systemeMessage.sender]];
	[[self.textView textStorage] appendAttributedString:systemeMessageAttributedString];
}

@end
