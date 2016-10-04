//
//  DARS.h
//  DARS
//
//  Created by E-Liang Tan on 14/4/12.
//  Copyright (c) 2012 E-Liang Tan. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

@class DARSDatabase;
@class DARSBrain;

/* 
 Possible Computer Responses:
 [unsure] Insufficient parameters. Please be more specific. (more sophisticated: Please specify: a name, a proton number, a chemical symbol)
 [wtf] Request not recognized.
 [out of my ability] Unable to comply.
 [result - single definition] The name is "hydrogen".
 [result - multiple definitions] Hydrogen has: chemical symbol H, proton number 1, relative atomic mass 1.
 [result - quantity] There are x atoms in the periodic table.
 */

extern NSString * const DARSUnknownTokenKeyword;

extern NSString * const DARSParsedDictionaryKeyword;
extern NSString * const DARSParsedDictionaryToken;
extern NSString * const DARSParsedDictionaryRange;
extern NSString * const DARSParsedDictionaryText; // This is an array containing dictionaries of keywords, tokens and ranges.
extern NSString * const DARSParsedDictionaryData; // This is an array of dictionaries of database information.

@protocol DARSDelegate;

enum _requestType {
	RequestTypeDefinition = 1 << 1,
	RequestTypeQuantity = 1 << 2,
	RequestTypeWhen = 1 << 3,
	RequestTypeWho = 1 << 4,
	RequestTypeLocation = 1 << 5,
	RequestTypeCause = 1 << 6,
	RequestTypeCourseOfAction = 1 << 7
};
typedef enum _requestType RequestType;

@interface DARS : NSObject

@property (nonatomic, strong) DARSBrain *brain;
@property (nonatomic, strong, readonly) NSMutableSet *databases; // Don't add any databases from outside. Use the methods provided
@property (nonatomic, assign) id<DARSDelegate> delegate;

- (id)initWithVocabularyFile:(NSString *)filePath;
- (BOOL)attachDatabase:(DARSDatabase *)database;
- (DARSDatabase *)databaseWithName:(NSString *)name;

- (void)getReplyFromInput:(NSString *)input; // Package method for the methods below. Returns reply through the DARS:didComputeReply:fromInput: delegate method.
- (NSDictionary *)parseString:(NSString *)string; // Returns a dictionary containing DARSParsedDictionaryText, DARSParsedDictionaryData. DARSParsedDictionaryText contains string of keyword, detected token, and range of token. DARSParsedDictionaryData contains fetched database data
- (NSString *)processParsedString:(NSDictionary *)parsedInformation originalString:(NSString *)string;
- (NSString *)replyToRequest:(NSString *)request ofType:(RequestType)requestType withObjects:(NSArray *)objects databaseData:(NSArray *)data;

@end

@protocol DARSDelegate <NSObject>
@optional
- (void)DARS:(DARS *)dars didComputeReply:(NSString *)reply fromInput:(NSString *)input;

@end
