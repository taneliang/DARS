//
//  DARS.m
//  DARS
//
//  Created by E-Liang Tan on 14/4/12.
//  Copyright (c) 2012 E-Liang Tan. All rights reserved.
//

#import "DARS.h"
#import "DARSDatabase.h"

NSString * const DARSUnknownTokenKeyword = @"internal.DARS.keyword.unknown";

NSString * const DARSParsedDictionaryKeyword = @"public.DARS.parsedict.key.keyword";
NSString * const DARSParsedDictionaryToken = @"public.DARS.parsedict.key.token";
NSString * const DARSParsedDictionaryRange = @"public.DARS.parsedict.key.range";

NSString * const DARSParsedDictionaryText = @"public.DARS.parsedict.key.text";
NSString * const DARSParsedDictionaryData = @"public.DARS.parsedict.key.data";

static NSString * const DARSPParsedDictionaryDataToken = @"private.DARS.parsedict.key.data.token";
static NSString * const DARSPParsedDictionaryDataDbColumn = @"private.DARS.parsedict.key.data.db_column";
static NSString * const DARSPParsedDictionaryDataActualData = @"private.DARS.parsedict.key.data.actual_data";

@implementation DARS

@synthesize brain = _brain;
@synthesize databases = _databases;
@synthesize delegate = _delegate;

- (id)initWithVocabularyFile:(NSString *)filePath {
	self = [super init];
	if (self != nil) {
		_databases = [NSMutableSet set];
		NSDictionary *vocabulary = [NSDictionary dictionaryWithDictionary:[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filePath] options:0 error:nil]];
		self.brain = [[DARSBrain alloc] initWithVocabularyFilePath:@"/Users/Eliang/Desktop/vocabulary.db"];
		[self.brain executeSQLQuery:@"DROP TABLE 'vocabulary'"];
		[self.brain executeSQLQuery:@"CREATE TABLE 'vocabulary' (token TEXT COLLATE NOCASE, keyword TEXT COLLATE NOCASE)"];
		
		[self.brain openSQLDatabase];
		for (NSString *key in [vocabulary allKeys]) {
			NSDictionary *list = [vocabulary objectForKey:key];
			for (NSDictionary *tokenSpecifier in [list objectForKey:@"tokens"]) {
				NSString *token = [tokenSpecifier objectForKey:@"token"];
				NSString *keyword = nil;
				if ([[tokenSpecifier allKeys] containsObject:@"keyword"]) keyword = [tokenSpecifier objectForKey:@"keyword"];
				else if ([[list allKeys] containsObject:@"default_keyword"]) keyword = [list objectForKey:@"default_keyword"];
				else keyword = DARSUnknownTokenKeyword;
				[self.brain executeSQLQuery:[NSString stringWithFormat:@"INSERT INTO 'vocabulary' VALUES(\"%@\", \"%@\")", token, keyword]];
			}
		}
		[self.brain closeSQLDatabase];
	}
	return self;
}

- (DARSDatabase *)databaseWithName:(NSString *)name {
	DARSDatabase *database;
	for (DARSDatabase *storedDatabase in [self.databases allObjects]) {
		if ([storedDatabase.databaseName isEqualToString:name]) {
			database = storedDatabase;
//			NSLog(@"DWN matched: %@", name);
			break;
		}
	}
	return database;
}

struct _DARSMathVariable {
	double value;
	char operators[];
};
typedef struct _DARSMathVariable DARSMathVariable;

- (double)doMath:(DARSMathVariable[])variables numberOfVariables:(int)numberOfVariables {
	// BODMAS
	BOOL hasExponents = NO;
	BOOL hasMultiplyDivide = NO;
	BOOL hasPlusMinus = NO;
	BOOL hasTwoSides = NO;
	for (int i = 0; i < numberOfVariables; i++) {
		for (int j = 0; j < strlen(variables[i].operators); j++) {
			char operator = variables[i].operators[j];
			if (operator == '+') hasPlusMinus = YES;
			if (operator == '-') hasPlusMinus = YES;
			if (operator == '*') hasMultiplyDivide = YES;
			if (operator == '/') hasMultiplyDivide = YES;
			if (operator == '^') hasExponents = YES;
//			if (operator == '\\') hasExponents = YES;
			if (operator == '=') hasTwoSides = YES;
		}
	}
	
}

- (void)getReplyFromInput:(NSString *)input {
	[self.brain emptyMentalMap];
	[self.brain loadMentalMapForInput:input];
	
	// Perhaps a SQLite table of databases can be maintained, taking advantage of the code already written for the databases.
	if ([input hasPrefix:@"attach database ("]) {
		NSScanner *scanner = [NSScanner scannerWithString:input];
		[scanner scanUpToString:@"(" intoString:nil];
		[scanner scanString:@"(" intoString:nil];
		NSString *databasePath = @"";
		[scanner scanUpToString:@")" intoString:&databasePath];
		[scanner scanUpToString:@"(" intoString:nil];
		[scanner scanString:@"(" intoString:nil];
		NSString *databaseAdaptorPath = @"";
		[scanner scanUpToString:@")" intoString:&databaseAdaptorPath];
		
		DARSDatabase *database = [[DARSDatabase alloc] initWithSQLite3DatabaseFilePath:databasePath databaseAdaptor:databaseAdaptorPath];
		BOOL attached = [self attachDatabase:database];
		if (attached) [self.delegate DARS:self didComputeReply:[NSString stringWithFormat:@"The database, \"%@\", has been successfully attached.", database.databaseName] fromInput:input];
		else [self.delegate DARS:self didComputeReply:[NSString stringWithFormat:@"I'm sorry, I failed to attach the database \"%@\".", database.databaseName] fromInput:input];
		return;
	}
	if ([input hasPrefix:@"detach database "]) {
		NSArray *components = [input componentsSeparatedByString:@" "];
		NSString *databaseName = [[components subarrayWithRange:NSMakeRange(2, [components count] - 2)] componentsJoinedByString:@" "];
		BOOL detached = [self detachDatabase:[self databaseWithName:databaseName]];
		if (detached) [self.delegate DARS:self didComputeReply:[NSString stringWithFormat:@"The database, \"%@\", has been successfully detached.", databaseName] fromInput:input];
		else [self.delegate DARS:self didComputeReply:[NSString stringWithFormat:@"I'm sorry, I failed to detach the database \"%@\".", databaseName] fromInput:input];
		return;
	}
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
//		NSDictionary *parsedString = [self parseString:input];
//		NSString *reply = [self processParsedString:parsedString originalString:input];
		NSString *reply;
		
		// Math
		NSMutableArray *mathOperators = [NSMutableArray array];
		BOOL hasMath = NO;
		for (DARSConcept *concept in self.brain.mentalMap.mainConcepts) {
			if ([concept.specialToken hasPrefix:@"DARS.specialtoken"]) {
				[mathOperators addObject:concept];
				if ([concept.specialToken hasPrefix:@"DARS.specialtoken.numeral"]) hasMath = YES;
			}
		}
		if (hasMath) {
			int variables[10000] = {};
			char operators[10000][5] = {};
			int numberVariables = 0;
			BOOL isBuildingVariable = NO;
			for (DARSConcept *concept in mathOperators) {
				if ([concept.specialToken hasPrefix:@"DARS.specialtoken.numeral"]) {
					if (isBuildingVariable == YES) {
						variables[numberVariables-1] *= 10;
					}
					else {
						numberVariables++;
						isBuildingVariable = YES;
					}
					int tokenValue = 0;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.zero"]) tokenValue = 0;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.one"]) tokenValue = 1;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.two"]) tokenValue = 2;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.three"]) tokenValue = 3;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.four"]) tokenValue = 4;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.five"]) tokenValue = 5;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.six"]) tokenValue = 6;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.seven"]) tokenValue = 7;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.eight"]) tokenValue = 8;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.numeral.nine"]) tokenValue = 9;
					variables[numberVariables-1] += tokenValue;
				}
				else if ([concept.specialToken hasPrefix:@"DARS.specialtoken.math.operator."]) {
					if (isBuildingVariable == YES) {
						isBuildingVariable = NO;
					}
					char operator = 0;
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.plus"]) operator = '+';
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.minus"]) operator = '-';
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.times"]) operator = '*';
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.divide"]) operator = '/';
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.power"]) operator = '^';
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.sqrt"]) operator = '\\';
					if ([concept.specialToken isEqualToString:@"DARS.specialtoken.math.operator.equal"]) operator = '=';
					operators[numberVariables][strlen(operators[numberVariables])] = operator;
				}
			}
			
			DARSMathVariable mathVariables[10000] = {};
			for (int i = 0; i < numberVariables; i++) {
				DARSMathVariable variable;
				variable.value = variables[i];
				for (int j = 0; j < strlen(operators[j]); j++) {
					variable.operators[j] = operators[i][j];
				}
				mathVariables[i] = variable;
			}
			double result = [self doMath:mathVariables numberOfVariables:numberVariables];
			reply = [NSString stringWithFormat:@"%f", result];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate DARS:self didComputeReply:reply fromInput:input];
		});
	});
}

- (NSDictionary *)parseString:(NSString *)string {
//	NSString *operationalString = [string lowercaseString];
	NSMutableArray *tokenKeywordArray = [NSMutableArray array];
	NSMutableCharacterSet *wordPaddingCharacterSet = [NSCharacterSet whitespaceCharacterSet];
	[wordPaddingCharacterSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
	
	NSArray *words = [[[string componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"?!,.'\"\\/|;:"]] componentsJoinedByString:@""] componentsSeparatedByString:@" "];

	for (NSUInteger i = 0; i < [words count]; i++) {
		NSString *column = nil;
		NSInteger displacement = 0;
		NSArray *result = [self.brain searchColumns:[NSArray arrayWithObject:@"token"] inTable:@"vocabulary" context:words valueIndexInContext:i wordSearchDisplacementFromValueInContext:&displacement foundInColumn:&column];
		if ([result count] > 0) {
			for (NSDictionary *resultingDictionary in result) {
				NSString *token = [resultingDictionary objectForKey:@"token"];
				NSString *keyword = [resultingDictionary objectForKey:@"keyword"];
				NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:token, DARSParsedDictionaryToken, keyword, DARSParsedDictionaryKeyword, NSStringFromRange(NSMakeRange(i, displacement+1)), DARSParsedDictionaryRange, nil];
				[tokenKeywordArray addObject:dictionary];
			}
		}
		i += displacement;
	}
	
	[tokenKeywordArray sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		NSRange range1 = NSRangeFromString([(NSDictionary *)obj1 objectForKey:DARSParsedDictionaryRange]);
		NSRange range2 = NSRangeFromString([(NSDictionary *)obj2 objectForKey:DARSParsedDictionaryRange]);
		if (range2.location == range1.location) {
			if (range1.length == range2.length) return NSOrderedSame;
			if (range1.length > range2.length) return NSOrderedDescending;
			if (range2.length > range1.length) return NSOrderedAscending;
		}
		if (range1.location > range2.location) return NSOrderedDescending;
		if (range2.location > range1.location) return NSOrderedAscending;
		return NSOrderedSame;
	}];
	
	NSMutableArray *mentionedDatabaseTables = [NSMutableArray array];
	for (NSDictionary *dictionary in tokenKeywordArray) {
		NSString *keyword = [dictionary objectForKey:DARSParsedDictionaryKeyword];
		if ([keyword hasPrefix:@"database_table"]) {
			NSArray *URIComponents = [keyword componentsSeparatedByString:@"."];
			NSString *mention = [[NSArray arrayWithObjects:[URIComponents objectAtIndex:1], [URIComponents objectAtIndex:2], nil] componentsJoinedByString:@"."];
			if (![mentionedDatabaseTables containsObject:mention]) {
				[mentionedDatabaseTables addObject:mention];
			}
		}
	}
	
	NSMutableArray *data = [NSMutableArray array];
	NSArray *allDatabases = [self.databases allObjects];
	for (DARSDatabase *database in allDatabases) {
		BOOL mentionedDatabase = NO;
		NSMutableArray *tables = [NSMutableArray array];
		
		for (NSString *mention in mentionedDatabaseTables) {
			NSArray *tableSpecifier = [mention componentsSeparatedByString:@"."];
			NSString *databaseName = [tableSpecifier objectAtIndex:0];
			if ([database.databaseName isEqualToString:databaseName]) {
				mentionedDatabase = YES;
				NSString *tableName = [tableSpecifier objectAtIndex:1];
				if (![tables containsObject:tableName]) {
					[tables addObject:tableName];
				}
			}
		}
		
		if (mentionedDatabase == YES) {
			for (NSUInteger i = 0; i < [words count]; i++) {
				NSString *word = [words objectAtIndex:i];
				for (NSString *table in tables) {
					NSString *column = nil;
					NSInteger displacement = 0;
					NSArray *result = [database searchColumns:nil inTable:table context:words valueIndexInContext:i wordSearchDisplacementFromValueInContext:&displacement foundInColumn:&column];
					i += displacement;
					if ([result count] > 0) {
						NSDictionary *dataDictionary = [NSDictionary dictionaryWithObjectsAndKeys:word, DARSPParsedDictionaryDataToken, [database naturalLanguageNameForColumn:column], DARSPParsedDictionaryDataDbColumn, result, DARSPParsedDictionaryDataActualData, nil];
						[data addObject:dataDictionary];
					}
				}
			}
		}
	}
	
	NSDictionary *parsedInformation = [NSDictionary dictionaryWithObjectsAndKeys:tokenKeywordArray, DARSParsedDictionaryText, data, DARSParsedDictionaryData, nil];
	
	return parsedInformation;
}

- (NSString *)processParsedString:(NSDictionary *)parsedInformation originalString:(NSString *)string {
	NSLog(@"PPSOS: %@", parsedInformation);
	if ([[parsedInformation objectForKey:DARSParsedDictionaryText] count] == 0 && [[parsedInformation objectForKey:DARSParsedDictionaryData] count] == 0) {
		return [NSString stringWithFormat:@"I don't understand what you mean by \"%@\"", string];
	}
	else if ([[parsedInformation objectForKey:DARSParsedDictionaryText] count] == 1 && [[parsedInformation objectForKey:DARSParsedDictionaryData] count] == 0 && [[[[parsedInformation objectForKey:DARSParsedDictionaryText] objectAtIndex:0] objectForKey:DARSParsedDictionaryKeyword] isEqualToString:@"address.computer"]) {
		return [NSString stringWithFormat:@"Why hello there. What may I do for you?", string];
	}
	
	RequestType requestType = 0;
	NSString *requestDescriptor = nil;
	NSMutableArray *requestObjects = [NSMutableArray array];
	
	NSMutableString *returnPrefix = [NSMutableString string];
	NSMutableString *returnBody = [NSMutableString string];
	NSMutableString *returnSuffix = [NSMutableString string];
	
	for (NSDictionary *dictionary in [parsedInformation objectForKey:DARSParsedDictionaryText]) {
		NSString *keyword = [dictionary objectForKey:DARSParsedDictionaryKeyword];
		if ([keyword hasPrefix:@"greetings"]) {
			if ([keyword isEqualToString:@"greetings.generic"]) {
				if ([returnPrefix rangeOfString:@"hi" options:NSCaseInsensitiveSearch].length == 0) {
					if ([returnPrefix length] > 0) [returnPrefix appendString:@" "];
					[returnPrefix appendString:@"Hello!"];
				}
			}
			if ([keyword isEqualToString:@"greetings.generic.reverse"]) {
				if ([returnSuffix rangeOfString:@"bye" options:NSCaseInsensitiveSearch].length == 0) {
					if ([returnSuffix length] > 0) [returnSuffix appendString:@" "];
					[returnSuffix appendString:@"Good bye!"];
				}
			}
			if ([keyword isEqualToString:@"greetings.timebased.morning"]) {
				if ([returnPrefix rangeOfString:@"good morning" options:NSCaseInsensitiveSearch].length == 0) {
					if ([returnPrefix length] > 0) [returnPrefix insertString:@" " atIndex:0];
					[returnPrefix insertString:@"Good morning!" atIndex:0];
				}
			}
			if ([keyword isEqualToString:@"greetings.timebased.afternoon"]) {
				if ([returnPrefix rangeOfString:@"good afternoon" options:NSCaseInsensitiveSearch].length == 0) {
					if ([returnPrefix length] > 0) [returnPrefix insertString:@" " atIndex:0];
					[returnPrefix insertString:@"Good afternoon!" atIndex:0];
				}
			}
			if ([keyword isEqualToString:@"greetings.timebased.evening"]) {
				if ([returnPrefix rangeOfString:@"good evening" options:NSCaseInsensitiveSearch].length == 0) {
					if ([returnPrefix length] > 0) [returnPrefix insertString:@" " atIndex:0];
					[returnPrefix insertString:@"Good evening!" atIndex:0];
				}
			}
			if ([keyword isEqualToString:@"greetings.timebased.night"]) {
				if ([returnPrefix rangeOfString:@"good night" options:NSCaseInsensitiveSearch].length == 0) {
					if ([returnPrefix length] > 0) [returnPrefix insertString:@" " atIndex:0];
					[returnPrefix insertString:@"Good night!" atIndex:0];
				}
			}
		}
		
		if ([keyword hasPrefix:@"query_type"]) {
			if ([keyword isEqualToString:@"query_type.definition"]) requestType = RequestTypeDefinition;
			if ([keyword isEqualToString:@"query_type.quantity"]) requestType = RequestTypeQuantity;
			if ([keyword isEqualToString:@"query_type.when"]) requestType = RequestTypeWhen;
			if ([keyword isEqualToString:@"query_type.who"]) requestType = RequestTypeWho;
			if ([keyword isEqualToString:@"query_type.location"]) requestType = RequestTypeLocation;
			if ([keyword isEqualToString:@"query_type.cause"]) requestType = RequestTypeCause;
			if ([keyword isEqualToString:@"query_type.courseofaction"]) requestType = RequestTypeCourseOfAction;
		}
		
		if ([keyword hasPrefix:@"request_descriptor"]) {
			requestDescriptor = keyword;
		}
		
		if ([keyword hasPrefix:@"request_object"] || [keyword hasPrefix:@"database_table"]) {
			[requestObjects addObject:dictionary];
		}
		
		if ([keyword hasPrefix:@"postrequestpadding"]) {
			if ([returnSuffix rangeOfString:@"no problem" options:NSCaseInsensitiveSearch].length == 0) {
				if ([returnSuffix length] > 0) [returnSuffix appendString:@" "];
				[returnSuffix appendString:@"No problem."];
			}
		}
	}
	
	if (requestType != 0 && (requestDescriptor == nil && requestObjects.count == 0)) {
		[returnBody appendString:@"Request not recognized. A request type was entered but no request descriptor or object was detected. (Error 1)"];
	}
	else if (requestDescriptor != nil && requestObjects.count == 0) {
		[returnBody appendString:@"Request not recognized. There wasn't any request that I could detect. (Error 2)"];
	}
	else {
		[returnBody appendFormat:@"%@", [self replyToRequest:requestDescriptor ofType:requestType withObjects:requestObjects databaseData:[parsedInformation objectForKey:DARSParsedDictionaryData]]];
	}
	
	if (returnPrefix.length > 0) [returnPrefix appendString:@" "];
	if (returnBody.length > 0) [returnBody appendString:@" "];
	NSString *returnString = [NSString stringWithFormat:@"%@%@%@", returnPrefix, returnBody, returnSuffix];
	return returnString;
}

- (NSString *)replyToRequest:(NSString *)request ofType:(RequestType)requestType withObjects:(NSArray *)objects databaseData:(NSArray *)data {
	NSLog(@"RTROTWO: %@ %d %@ %@", request, requestType, objects, data);
	NSMutableString *returnString = [NSMutableString string];
	
	switch (requestType) {
		case 0:
		case RequestTypeDefinition: {
			if ([data count] <= 0) break;
			
			NSString *dbColumn = nil;
			BOOL hasMoreThanOneDbColumn = NO;
			
			NSMutableArray *uniqueObjects = [NSMutableArray array];
			for (NSDictionary *dataDictionary in data) {
				NSArray *actualData = [dataDictionary objectForKey:DARSPParsedDictionaryDataActualData];
				for (NSDictionary *dataDictionary in actualData) {
					if (![uniqueObjects containsObject:dataDictionary]) {
						[uniqueObjects addObject:dataDictionary];
					}
				}
				
				if (hasMoreThanOneDbColumn == NO) {
					NSString *columnName = [dataDictionary objectForKey:DARSPParsedDictionaryDataDbColumn];
					if (dbColumn != nil && ![columnName isEqualToString:dbColumn]) hasMoreThanOneDbColumn = YES;
					else dbColumn = columnName;
				}
			}
			
			NSMutableArray *mentionedColumnNames = [NSMutableArray array];
			for (NSDictionary *object in objects) {
				NSString *keyword = [object objectForKey:DARSParsedDictionaryKeyword];
				NSArray *URIComponents = [keyword componentsSeparatedByString:@"."];
				if ([URIComponents count] == 6 && [[URIComponents objectAtIndex:3] isEqualToString:@"column"]) {
					NSString *databaseName = [URIComponents objectAtIndex:1];
					DARSDatabase *database = [self databaseWithName:databaseName];
					NSString *columnName = [database naturalLanguageNameForColumn:[URIComponents objectAtIndex:4]];
					if (![mentionedColumnNames containsObject:columnName]) {
						[mentionedColumnNames addObject:columnName];
					}
				}
			}
			
			if (hasMoreThanOneDbColumn == NO) {
				[mentionedColumnNames removeObject:dbColumn];
			}
			
			NSInteger numberOfObjects = [uniqueObjects count];
			NSInteger objectIndexCounter = 0;
			if (numberOfObjects > 1) [returnString appendFormat:@"Here are the details: "];
			for (NSDictionary *dataDictionary in uniqueObjects) {
				if (numberOfObjects > 1)[returnString appendFormat:@"\n%d) ", ++objectIndexCounter];
				NSMutableArray *array = [NSMutableArray array];
				// If objects (token) contains dbcolumn and no other column names, display all details
				// If objects (token) contains dbcolumn and other column names, display only those column names
				// If objects (token) contains no column names, display all details
				// If objects (token) contains column names but not dbcolumn, display only those columns
				for (NSString *key in [dataDictionary allKeys]) {
					BOOL shouldPrintThisKey = NO;
					if (hasMoreThanOneDbColumn == YES) shouldPrintThisKey = YES;
					else if ([mentionedColumnNames count] == 0) shouldPrintThisKey = YES;
					else if ([mentionedColumnNames containsObject:key]) shouldPrintThisKey = YES;
					if (shouldPrintThisKey == YES) [array addObject:[NSString stringWithFormat:@"%@ is %@", key, [dataDictionary objectForKey:key]]];
				}
				
				// Capitalize first word
				if ([array count] > 0) {
//					NSMutableArray *firstItemArray = [NSMutableArray arrayWithArray:[[array objectAtIndex:0] componentsSeparatedByString:@" "]];
//					[firstItemArray insertObject:[[firstItemArray objectAtIndex:0] capitalizedString] atIndex:0];
//					[firstItemArray removeObjectAtIndex:1];
//					NSString *newFirstItem = [firstItemArray componentsJoinedByString:@" "];
//					[array removeObjectAtIndex:0];
//					[array insertObject:newFirstItem atIndex:0];
					
					[returnString appendString:@"The "];
					if ([array count] == 1) {
						[returnString appendString:[array objectAtIndex:0]];
					}
					else {
						[returnString appendString:[[array subarrayWithRange:NSMakeRange(0, [array count]-1)] componentsJoinedByString:@", "]];
						[returnString appendFormat:@" and %@", [array lastObject]];
					}
					[returnString appendString:@"."];
				}
			}
			break;
		}
		case RequestTypeQuantity: {
			NSString *databaseName = nil;
			NSString *tableName = nil;
			NSString *quantifiedObject = nil;
			for (NSDictionary *object in objects) {
				NSString *keyword = [object objectForKey:DARSParsedDictionaryKeyword];
				if ([keyword hasSuffix:@"contents_name"]) {
					NSArray *URIComponents = [keyword componentsSeparatedByString:@"."];
					databaseName = [URIComponents objectAtIndex:1];
					tableName = [URIComponents objectAtIndex:2];
					quantifiedObject = [object objectForKey:DARSParsedDictionaryToken];
				}
			}
			
			if ([request isEqualToString:@"request_descriptor.thingsin"]) {
				
				DARSDatabase *database = [self databaseWithName:databaseName];
				
				NSArray *result = [database executeSQLQuery:[NSString stringWithFormat:@"SELECT COUNT() FROM '%@'", tableName]];
//				NSLog(@"%@ %@ %@", tableName, database, result);
				NSNumber *quantity = [[result objectAtIndex:0] objectForKey:@"COUNT()"];
				[returnString appendFormat:@"There are %@ %@.", quantity, quantifiedObject];
			}
			else {
				NSInteger quantity = 0;
				for (NSDictionary *dataDictionary in data) {
					quantity += [[dataDictionary objectForKey:DARSPParsedDictionaryDataActualData] count];
				}
				[returnString appendFormat:@"There are %d %@.", quantity, quantifiedObject];
			}
			break;
		}
		default:
			break;
	}
	
	return returnString;
}

- (BOOL)attachDatabase:(DARSDatabase *)database {
	if ([self.databases containsObject:database]) {
		return NO;
	}
	for (DARSDatabase *storedDatabase in self.databases) {
		if ([storedDatabase.databaseFilePath isEqualToString:database.databaseFilePath]) {
			return NO;
		}
	}
	
	[self.brain openSQLDatabase];
	for (NSDictionary *tokenSpecifier in database.requiredVocabulary) {
		NSString *token = [tokenSpecifier objectForKey:@"token"];
		NSString *keyword = [tokenSpecifier objectForKey:@"keyword"];
		[self.brain executeSQLQuery:[NSString stringWithFormat:@"INSERT INTO 'vocabulary' VALUES(\"%@\", \"%@\")", token, keyword]];
	}
	[self.brain closeSQLDatabase];
	[self.databases addObject:database];
	
	return YES;
}

- (BOOL)detachDatabase:(DARSDatabase *)database {
	if (![self.databases containsObject:database]) {
		return NO;
	}
	
	// Clear vocabularyDatabase of vocabulary
	NSMutableArray *tokens = [NSMutableArray arrayWithCapacity:[database.requiredVocabulary count]];
	for (NSDictionary *tokenSpecifier in database.requiredVocabulary) {
		NSString *token = [NSString stringWithFormat:@"'%@'", [tokenSpecifier objectForKey:@"token"]];
		[tokens addObject:token];
	}
	[self.brain executeSQLQuery:[NSString stringWithFormat:@"DELETE FROM 'vocabulary' WHERE token IN (%@)", [tokens componentsJoinedByString:@","]]];
	[self.databases removeObject:database];
	return YES;
}

@end
