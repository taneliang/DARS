//
//  DARSDatabase.m
//  DARS
//
//  Created by E-Liang Tan on 3/5/12.
//  Copyright (c) 2012 E-Liang Tan. All rights reserved.
//

#import "DARSDatabase.h"

@implementation DARSDatabase

@synthesize databaseName = _databaseName;
@synthesize databaseFilePath = _databaseFilePath;
//@synthesize database = _database;
@synthesize databaseInformation = _databaseInformation;
@synthesize requiredVocabulary = _requiredVocabulary;
@synthesize database = _database;

- (void)addRequiredVocabularyWithToken:(NSString *)token keyword:(NSString *)keyword {
	[self.requiredVocabulary addObject:[NSDictionary dictionaryWithObjectsAndKeys:token, @"token", keyword, @"keyword", nil]];
}

- (id)initWithSQLite3DatabaseFilePath:(NSString *)filePath databaseAdaptor:(NSString *)dbAdaptorPath {
	self = [super init];
	if (self) {
		_databaseFilePath = filePath;
		NSError *error = nil;
		if (dbAdaptorPath) {
			self.databaseInformation = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:dbAdaptorPath] options:0 error:&error];
			_databaseName = [self.databaseInformation objectForKey:@"database_name"];
			self.requiredVocabulary = [NSMutableArray array];
			for (NSDictionary *tableInformation in [self.databaseInformation objectForKey:@"tables"]) {
				NSString *tableName = [tableInformation objectForKey:@"table_name"];
				[self addRequiredVocabularyWithToken:[tableInformation objectForKey:@"table_natural_language_name"] keyword:[[NSArray arrayWithObjects:@"database_table", self.databaseName, tableName, @"database_name", nil] componentsJoinedByString:@"."]];
				
				NSString *tableContentsKeyword = [[NSArray arrayWithObjects:@"database_table", self.databaseName, tableName, @"contents_name", nil] componentsJoinedByString:@"."];
				[self addRequiredVocabularyWithToken:[tableInformation objectForKey:@"table_contents_plural"] keyword:tableContentsKeyword];
				[self addRequiredVocabularyWithToken:[tableInformation objectForKey:@"table_contents_singular"] keyword:tableContentsKeyword];
				
				for (NSDictionary *columnInformation in [tableInformation objectForKey:@"columns"]) {
					NSString *columnName = [columnInformation objectForKey:@"column_name"];
					[self addRequiredVocabularyWithToken:[columnInformation objectForKey:@"column_natural_language_name"] keyword:[[NSArray arrayWithObjects:@"database_table", self.databaseName, tableName, @"column", columnName, @"column_name", nil] componentsJoinedByString:@"."]];
					
					NSString *columnContentsKeyword = [[NSArray arrayWithObjects:@"database_table", self.databaseName, tableName, @"column", columnName, @"column_contents_name", nil] componentsJoinedByString:@"."];
					[self addRequiredVocabularyWithToken:[columnInformation objectForKey:@"column_contents_plural"] keyword:columnContentsKeyword];
					[self addRequiredVocabularyWithToken:[columnInformation objectForKey:@"column_contents_singular"] keyword:columnContentsKeyword];
				}
			}
		}
		self.database = NULL;
	}
	return self;
}

- (NSString *)naturalLanguageNameForColumn:(NSString *)columnName {
	for (NSDictionary *tableInformation in [self.databaseInformation objectForKey:@"tables"]) {
		for (NSDictionary *columnInformation in [tableInformation objectForKey:@"columns"]) {
			if ([[columnInformation objectForKey:@"column_name"] isEqualToString:columnName]) {
				return [columnInformation objectForKey:@"column_natural_language_name"];
			}
		}
	}
	return columnName;
}

- (NSString *)columnNameForNaturalLanguageName:(NSString *)nlangName {
	for (NSDictionary *tableInformation in [self.databaseInformation objectForKey:@"tables"]) {
		for (NSDictionary *columnInformation in [tableInformation objectForKey:@"columns"]) {
			if ([[columnInformation objectForKey:@"column_natural_language_name"] isEqualToString:nlangName]) {
				return [columnInformation objectForKey:@"column_name"];
			}
		}
	}
	return nlangName;
}

- (NSArray *)whereColumnStatementsWithFormatString:(NSString *)format tableName:(NSString *)tableName searchColumnNames:(NSArray *)searchColumnNames value:(NSString *)value correspondingColumnNames:(NSArray **)columnNames {
	NSMutableArray *mutableColumnNames = [NSMutableArray array];
	NSMutableArray *whereColumnStatements = [NSMutableArray array];
	for (NSDictionary *tableInformation in [self.databaseInformation objectForKey:@"tables"]) {
		if ([[tableInformation objectForKey:@"table_name"] isEqualToString:tableName]) {
			for (NSDictionary *columnInformation in [tableInformation objectForKey:@"columns"]) {
				NSString *columnName = [columnInformation objectForKey:@"column_name"];
				if (searchColumnNames == nil || [searchColumnNames containsObject:columnName]) {
					[whereColumnStatements addObject:[NSString stringWithFormat:format, columnName, value]];
					[mutableColumnNames addObject:columnName];
				}
			}
		}
	}
	*columnNames = mutableColumnNames;
	return whereColumnStatements;
}

- (NSArray *)searchColumns:(NSArray *)searchColumnNames inTable:(NSString *)tableName context:(NSArray *)context valueIndexInContext:(NSUInteger)vindex wordSearchDisplacementFromValueInContext:(NSInteger *)dist foundInColumn:(NSString **)column {
	if (context == nil || [context count] <= 0 || tableName == nil) {
		return nil;
	}
	
	NSInteger maxPositiveDisplacement = [context count] - (vindex + 1);
	NSMutableArray *usableValue = [NSMutableArray array];
	
	[self openSQLDatabase];
	
	BOOL hasAlreadyGottenPositiveCount = NO;
	BOOL hasPassedThreshold = NO;
	int count = 0;
	for ((*dist) = 0; (*dist) <= maxPositiveDisplacement; (*dist)++) {
		NSArray *columnNames = nil;
		if (hasPassedThreshold == NO) {
			[usableValue addObject:[context objectAtIndex:vindex + (*dist)]];
			NSArray *whereColumnStatements = [self whereColumnStatementsWithFormatString:@"%@ LIKE '%%%@%%'" tableName:tableName searchColumnNames:searchColumnNames value:[usableValue componentsJoinedByString:@" "] correspondingColumnNames:&columnNames];
			NSString *whereStatement = [whereColumnStatements componentsJoinedByString:@" OR "];
			NSString *query = [NSString stringWithFormat:@"SELECT COUNT() FROM '%@' WHERE (%@)", tableName, whereStatement];
			NSArray *result = [self executeSQLQuery:query];
			count = [[[result lastObject] objectForKey:@"COUNT()"] intValue];
		}
		else (*dist)--;
		if (count > 0) {
			hasAlreadyGottenPositiveCount = YES;
		}
		if (count == 1 || (count == 0 && hasAlreadyGottenPositiveCount == YES) || (hasAlreadyGottenPositiveCount == YES && (*dist) == maxPositiveDisplacement)) {
			hasPassedThreshold = YES;
			if (count == 0 && hasAlreadyGottenPositiveCount == YES) {
				[usableValue removeLastObject];
				(*dist)--;
			}
			NSArray *whereColumnStatements = [self whereColumnStatementsWithFormatString:@"%@ == '%@'" tableName:tableName searchColumnNames:searchColumnNames value:[usableValue componentsJoinedByString:@" "] correspondingColumnNames:&columnNames];
			NSString *whereStatement = [whereColumnStatements componentsJoinedByString:@" OR "];
			NSString *query = [NSString stringWithFormat:@"SELECT * FROM '%@' WHERE (%@)", tableName, whereStatement];
			NSArray *result = [self executeSQLQuery:query];
			if ([result count] != 0) {
				// Find columns
				
				for (NSUInteger i = 0; i < [whereColumnStatements count]; i++) {
					NSString *whereStatement = [whereColumnStatements objectAtIndex:i];
					NSString *query = [NSString stringWithFormat:@"SELECT * FROM '%@' WHERE (%@)", tableName, whereStatement];
					NSArray *result = [self executeSQLQuery:query];
					if ([result count] > 0) {
						*column = [columnNames objectAtIndex:i];
						break;
					}
				}
				
				[self closeSQLDatabase];
				return result;
			}
			else if (*dist == 0) {
				[self closeSQLDatabase];
				return result;
			}
		}
	}
	
	[self closeSQLDatabase];
	
	*dist = 0;
	return [NSArray array];
}

- (BOOL)openSQLDatabase {
	if (self.database != NULL) return NO;
	int openResult = sqlite3_open([self.databaseFilePath UTF8String], &_database);
	if (openResult == SQLITE_OK) return YES;
	else NSLog(@"DARSDatabase %@ (%@) could not open SQLiteDatabase with error %d %s", self, self.databaseName, openResult, sqlite3_errmsg(self.database));
	return NO;
}

- (BOOL)closeSQLDatabase {
	if (self.database == NULL) return NO;
	int closeResult = sqlite3_close(self.database);
	if (closeResult == SQLITE_OK) {
		self.database = NULL;
		return YES;
	}
	else NSLog(@"DARSDatabase %@ (%@) could not close SQLiteDatabase with error %d %s", self, self.databaseName, closeResult, sqlite3_errmsg(self.database));
	return NO;
}

- (NSArray *)executeSQLQuery:(NSString *)query {
	BOOL wasDatabaseOpen = NO;
	if (self.database != NULL) wasDatabaseOpen = YES;
	[self openSQLDatabase];
	
	sqlite3_stmt *statement;
	int prepareResult = sqlite3_prepare_v2(self.database, [query UTF8String], -1, &statement, NULL);
	if (prepareResult != SQLITE_OK) {
		NSLog(@"DARSDatabase %@ (%@) could not prepare statement for query \"%@\" with error %d %s", self, self.databaseName, query, prepareResult, sqlite3_errmsg(self.database));
		return nil;
	}
	
	NSMutableArray *resultsOfQuery = [NSMutableArray array];
	int sqliteStep = -1;
	while (sqliteStep != SQLITE_DONE) {
		sqliteStep = sqlite3_step(statement);
		if (sqliteStep != SQLITE_ROW) {
			if (sqliteStep == SQLITE_DONE) break;
			else NSLog(@"DARSDatabase %@ (%@) failed to run sqlite3_step() for query \"%@\" with error %d %s", self, self.databaseName, query, sqliteStep, sqlite3_errmsg(self.database));
		}
		// Build up NSDictionary, add to results
		NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
		int columnCount = sqlite3_column_count(statement);
		for (int i = 0; i < columnCount; i++) {
			NSString *columnName = [self naturalLanguageNameForColumn:[NSString stringWithUTF8String:sqlite3_column_name(statement, i)]];
			int columnType = sqlite3_column_type(statement, i);
			
			if (columnType == SQLITE_INTEGER) [dictionary setObject:[NSNumber numberWithInt:sqlite3_column_int(statement, i)] forKey:columnName];
			else if (columnType == SQLITE_FLOAT) [dictionary setObject:[NSNumber numberWithDouble:sqlite3_column_double(statement, i)] forKey:columnName];
			else if (columnType == SQLITE3_TEXT) [dictionary setObject:[NSString stringWithUTF8String:(const char *)sqlite3_column_text(statement, i)] forKey:columnName];
			else if (columnType != SQLITE_NULL) {
				NSLog(@"DARSDatabase %@ (%@) failed to store a result for query \"%@\" with column name %@ type %d", self, self.databaseName, query, columnName, columnType);
			}
		}
		
		[resultsOfQuery addObject:dictionary];
	}
	
	sqlite3_finalize(statement);
	
	if (wasDatabaseOpen == NO) [self closeSQLDatabase];
	return resultsOfQuery;
}

@end

@implementation DARSBrain

@synthesize mentalMap = _mentalMap;

- (id)initWithVocabularyFilePath:(NSString *)filePath {
	self = [super initWithSQLite3DatabaseFilePath:filePath databaseAdaptor:[[NSBundle mainBundle] pathForResource:@"vocabulary_db" ofType:@"js"]];
	if (self) {
		self.mentalMap = [[DARSMentalMap alloc] initWithBrain:self];
	}
	return self;
}

- (void)dropCreateTables {
	[self executeSQLQuery:@"DROP TABLE 'concept'"];
	[self executeSQLQuery:@"DROP TABLE 'concept_linker'"];
	[self executeSQLQuery:@"DROP TABLE 'concept_natural_language_representer'"];
	[self executeSQLQuery:@"DROP TABLE 'concept_natural_language_representer_linker'"];
	[self executeSQLQuery:@"DROP TABLE 'concept_property'"];
	[self executeSQLQuery:@"CREATE TABLE 'concept' (id INTEGER PRIMARY KEY, special_token TEXT)"];
	[self executeSQLQuery:@"CREATE TABLE 'concept_linker' (id INTEGER PRIMARY KEY, concept_one INTEGER NOT NULL, concept_two INTEGER, mental_map_string_rep TEXT, linker_type INTEGER, FOREIGN KEY(concept_one) REFERENCES concept(id), FOREIGN KEY(concept_two) REFERENCES concept(id))"];
	[self executeSQLQuery:@"CREATE TABLE 'concept_natural_language_representer' (id INTEGER PRIMARY KEY, text TEXT COLLATE NOCASE, part_of_speech INTEGER)"];
	[self executeSQLQuery:@"CREATE TABLE 'concept_natural_language_representer_linker' (id INTEGER PRIMARY KEY, representer_id INTEGER NOT NULL, concept_id INTEGER NOT NULL, FOREIGN KEY(representer_id) REFERENCES concept_natural_language_representer(id), FOREIGN KEY(concept_id) REFERENCES concept(id))"];
	[self executeSQLQuery:@"CREATE TABLE 'concept_property' (id INTEGER PRIMARY KEY, host_concept_id INTEGER NOT NULL, property TEXT NOT NULL, FOREIGN KEY(host_concept_id) REFERENCES concept(id))"];
}

- (void)resetVocabulary:(NSString *)vocabularyDocumentFilePath {
	[self openSQLDatabase];
	[self dropCreateTables];
	
	NSError *error = nil;
	NSString *vocabularyDoc = [NSString stringWithContentsOfFile:vocabularyDocumentFilePath encoding:NSUTF8StringEncoding error:&error];
	if (error) {
		NSLog(@"DARSBrain (%@) -resetVocabulary: encountered a problem opening vocabulary file. %@", self, error);
		[self closeSQLDatabase];
		return;
	}
	
	NSArray *lines = [vocabularyDoc componentsSeparatedByString:@"\n"];
	NSUInteger conceptIDCounter = 0;
	for (NSString *line in lines) {
		if (line.length > 0) {
			NSScanner *scanner = [NSScanner scannerWithString:line];
			NSString *words = nil;
			BOOL scannedWords = [scanner scanUpToString:@": " intoString:&words];
			[scanner scanString:@": " intoString:nil];
			NSString *links = nil;
			BOOL scannedLinks = [scanner scanUpToString:@";" intoString:&links];
			if (scannedLinks == NO && scannedWords == YES) {
				scanner = [NSScanner scannerWithString:words];
				scannedWords = [scanner scanUpToString:@";" intoString:&words];
				scanner = [NSScanner scannerWithString:words];
				scannedWords = [scanner scanUpToString:@"//" intoString:&words];
			}
			if (scannedWords == YES) {
				NSArray *wordArray = [words componentsSeparatedByString:@", "];
				NSArray *linkArray = [links componentsSeparatedByString:@", "];
				NSMutableArray *conceptLinks = [NSMutableArray arrayWithCapacity:[lines count]];
				NSMutableArray *conceptProperties = [NSMutableArray array];
				NSString *specialToken = nil;
				for (NSString *link in linkArray) {
					scanner = [NSScanner scannerWithString:link];
					[scanner scanUpToString:@"(" intoString:nil];
					[scanner scanString:@"(" intoString:nil];
					NSString *linkContent = nil;
					[scanner scanUpToString:@")" intoString:&linkContent];
					if ([link hasPrefix:@"INSTANCE"]) {
						[conceptLinks addObject:[NSDictionary dictionaryWithObjectsAndKeys:linkContent, @"word", [NSNumber numberWithInt:DARSBrainConceptLinkerTypeInstance], @"linkerType", nil]];
					}
					else if ([link hasPrefix:@"CONTAINS"]) {
						[conceptLinks addObject:[NSDictionary dictionaryWithObjectsAndKeys:linkContent, @"word", [NSNumber numberWithInt:DARSBrainConceptLinkerTypeContains], @"linkerType", nil]];
					}
					else if ([link hasPrefix:@"PROPERTY"]) {
						NSArray *linkContentContent = [linkContent componentsSeparatedByString:@", "];
						[conceptProperties addObject:[NSDictionary dictionaryWithObjectsAndKeys:[linkContentContent objectAtIndex:0], @"property_name", [linkContentContent objectAtIndex:1], @"property", nil]];
					}
					else if ([link hasPrefix:@"STOKEN"]) {
						specialToken = linkContent;
					}
				}
				
				NSString *query = [NSString stringWithFormat:@"INSERT INTO concept VALUES(%ld, %@)", ++conceptIDCounter, (specialToken ? [NSString stringWithFormat:@"'%@'", specialToken] : @"NULL")];
				[self executeSQLQuery:query];
				for (NSString *word in wordArray) {
					[self addWord:word forConcept:conceptIDCounter];
				}
				for (NSDictionary *link in conceptLinks) {
					NSArray *results = [self conceptsForWord:[link objectForKey:@"word"]];
					[self linkConcept:conceptIDCounter withConcept:[(DARSConcept *)[results lastObject] identifier] linkerType:[[link objectForKey:@"linkerType"] integerValue]];
				}
				for (NSDictionary *property in conceptProperties) {
					[self addProperty:[property objectForKey:@"property"] forConcept:conceptIDCounter];
				}
			}
		}
	}
	[self closeSQLDatabase];
}

- (DARSConcept *)conceptWithID:(NSInteger)identifier {
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM concept WHERE id == %ld", identifier];
	NSArray *results = [self executeSQLQuery:query];
	NSDictionary *result = [results lastObject];
	DARSConcept *object = [[DARSConcept alloc] initWithHostMentalMap:self.mentalMap];
	object.identifier = [[result objectForKey:@"id"] integerValue];
	if ([[result allKeys] containsObject:@"special_token"]) object.specialToken = [result objectForKey:@"special_token"];
	return object;
}

- (NSArray *)conceptsForWord:(NSString *)word {
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM concept WHERE id IN (SELECT concept_id FROM concept_natural_language_representer_linker WHERE (representer_id IN (SELECT id FROM concept_natural_language_representer WHERE text == '%@')))", word];
	NSArray *results = [self executeSQLQuery:query];
	NSMutableArray *realResults = [NSMutableArray arrayWithCapacity:[results count]];
	for (NSDictionary *result in results) {
		DARSConcept *object = [[DARSConcept alloc] initWithHostMentalMap:self.mentalMap];
		object.identifier = [[result objectForKey:@"id"] integerValue];
		if ([[result allKeys] containsObject:@"special_token"]) object.specialToken = [result objectForKey:@"special_token"];
		[realResults addObject:object];
	}
	return realResults;
}

- (NSArray *)wordsForConcept:(NSInteger)identifier {
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM concept_natural_language_representer WHERE id IN (SELECT representer_id FROM concept_natural_language_representer_linker WHERE concept_id == %ld)", identifier];
	NSArray *results = [self executeSQLQuery:query];
	NSMutableArray *realResults = [NSMutableArray arrayWithCapacity:[results count]];
	for (NSDictionary *result in results) {
		DARSNaturalLanguageRepresenter *object = [[DARSNaturalLanguageRepresenter alloc] initWithHostMentalMap:self.mentalMap];
		object.identifier = [[result objectForKey:@"id"] integerValue];
		object.text = [result objectForKey:@"text"];
		object.partOfSpeech = [[result objectForKey:@"part_of_speech"] integerValue];
		[realResults addObject:object];
	}
	return realResults;
}

- (NSArray *)conceptLinkersForConcept:(NSInteger)identifier {
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM concept_linker WHERE concept_one == %ld OR concept_two == %ld", identifier, identifier];
	NSArray *results = [self executeSQLQuery:query];
	NSMutableArray *realResults = [NSMutableArray arrayWithCapacity:[results count]];
	for (NSDictionary *result in results) {
		DARSConceptLinker *object = [[DARSConceptLinker alloc] initWithHostMentalMap:self.mentalMap];
		object.identifier = [[result objectForKey:@"id"] integerValue];
		object.conceptOneIdentifier = [[result objectForKey:@"concept_one"] integerValue];
		if ([[result allKeys] containsObject:@"concept_two"]) object.conceptTwoIdentifier = [[result objectForKey:@"concept_two"] integerValue];
		object.linkerType = [[result objectForKey:@"linker_type"] integerValue];
//		if ([[result allKeys] containsObject:@"mental_map_string_rep"]) object.mentalMap = [[result objectForKey:@"mental_map_string_rep"] integerValue];
		[realResults addObject:object];
	}
	return realResults;
}

- (NSArray *)representersWithText:(NSString *)text {
	NSString *query = nil;
	NSArray *results = nil;
	query = [NSString stringWithFormat:@"SELECT * FROM concept_natural_language_representer WHERE text == '%@'", text];
	results = [self executeSQLQuery:query];
	NSMutableArray *realResults = [NSMutableArray arrayWithCapacity:[results count]];
	for (NSDictionary *result in results) {
		DARSNaturalLanguageRepresenter *object = [[DARSNaturalLanguageRepresenter alloc] initWithHostMentalMap:self.mentalMap];
		object.identifier = [[result objectForKey:@"id"] integerValue];
		object.text = [result objectForKey:@"text"];
		object.partOfSpeech = [[result objectForKey:@"part_of_speech"] integerValue];
		[realResults addObject:object];
	}
	return realResults;
}

- (void)addWord:(NSString *)word forConcept:(NSInteger)concept {
	NSString *query = nil;
	NSArray *results = nil;
	
	// Check if word exists. If exists, add link. If doens't exist, add word, then add link. Add link: check if link exists. If doesn't exist, add link
	results = [self representersWithText:word];
	if ([results count] == 0) {
		query = [NSString stringWithFormat:@"INSERT INTO concept_natural_language_representer (text, part_of_speech) VALUES('%@', -1)", word];
		[self executeSQLQuery:query];
		results = [self representersWithText:word];
	}
	NSInteger representerID = [(DARSNaturalLanguageRepresenter *)[results lastObject] identifier];
	query = [NSString stringWithFormat:@"SELECT COUNT() FROM concept_natural_language_representer_linker WHERE representer_id == %ld AND concept_id == %ld", representerID, concept];
	results = [self executeSQLQuery:query];
	if ([[[results lastObject] objectForKey:@"COUNT()"] integerValue] <= 0) {
		query = [NSString stringWithFormat:@"INSERT INTO concept_natural_language_representer_linker (representer_id, concept_id) VALUES(%ld, %ld)", representerID, concept];
		[self executeSQLQuery:query];
	}
}

- (void)linkConcept:(NSInteger)conceptOne withConcept:(NSInteger)conceptTwo linkerType:(DARSBrainConceptLinkerType)linkerType {
	NSString *query = nil;
	NSArray *results = nil;
	
	// Check if link exists
	query = [NSString stringWithFormat:@"SELECT COUNT() FROM concept_linker WHERE ((concept_one == %ld AND concept_two == %ld) OR (concept_one == %ld AND concept_two == %ld)) AND linker_type == %ld", conceptOne, conceptTwo, conceptTwo, conceptOne, linkerType];
	results = [self executeSQLQuery:query];
	if ([[[results lastObject] objectForKey:@"COUNT()"] integerValue] <= 0) {
		query = [NSString stringWithFormat:@"INSERT INTO concept_linker (concept_one, concept_two, linker_type) VALUES(%ld, %ld, %ld)", conceptOne, conceptTwo, linkerType];
		[self executeSQLQuery:query];
	}
}

- (void)addProperty:(NSString *)property forConcept:(NSInteger)concept {
	NSString *query = nil;
	NSArray *results = nil;
	
	// Check if property exists
	query = [NSString stringWithFormat:@"SELECT COUNT() FROM concept_property WHERE host_concept_id == %ld AND property == '%@'", concept, property];
	results = [self executeSQLQuery:query];
	if ([[[results lastObject] objectForKey:@"COUNT()"] integerValue] <= 0) {
		query = [NSString stringWithFormat:@"INSERT INTO concept_property (host_concept_id, property) VALUES(%ld, '%@')", concept, property];
		[self executeSQLQuery:query];
	}
}

- (void)assimilateDatabase:(DARSDatabase *)database {
	
}

- (void)emptyMentalMap {
	[self.mentalMap.mainConcepts removeAllObjects];
}

- (void)loadMentalMapForInput:(NSString *)input {
	NSArray *words = [input componentsSeparatedByString:@" "];
	for (NSString *word in words) {
		NSArray *concepts = [self conceptsForWord:word];
		if ([concepts count] > 0) {
			[self.mentalMap.mainConcepts addObjectsFromArray:concepts];
		}
		else {
			const char *characters = [word UTF8String];
			for (int i = 0; i < strlen(characters); i++) {
				concepts = [self conceptsForWord:[NSString stringWithUTF8String:(const char[]){ characters[i], '\0' }]];
				[self.mentalMap.mainConcepts addObjectsFromArray:concepts];
			}
		}
	}
	NSLog(@"LMMFI: %@ %@", self.mentalMap.mainConcepts, input);
}

- (NSString *)describeCurrentMentalMap {
	return @"";
}

- (void)findPathBetweenConcept:(DARSConcept *)conceptOne andConcept:(DARSConcept *)conceptTwo {
	
}

@end

@implementation DARSConcept 

@synthesize mentalMap = _mentalMap;
@synthesize identifier;
@synthesize specialToken;
@synthesize conceptLinkers;
@synthesize naturalLanguageRepresenters;

- (id)initWithHostMentalMap:(DARSMentalMap *)mentalMap {
	self = [super init];
	if (self) {
		self.mentalMap = mentalMap;
	}
	return self;
}

- (NSMutableArray *)conceptLinkers {
	if (conceptLinkers == nil) {
		conceptLinkers = [[NSMutableArray alloc] init];
		NSArray *concepts = [self.mentalMap.brain conceptLinkersForConcept:self.identifier];
		[conceptLinkers addObjectsFromArray:concepts];
	}
	return conceptLinkers;
}

- (NSMutableArray *)naturalLanguageRepresenters {
	if (naturalLanguageRepresenters == nil) {
		naturalLanguageRepresenters = [[NSMutableArray alloc] init];
		NSArray *representers = [self.mentalMap.brain wordsForConcept:self.identifier];
		[naturalLanguageRepresenters addObjectsFromArray:representers];
	}
	return naturalLanguageRepresenters;
}

@end

@implementation DARSConceptLinker 

@synthesize mentalMap = _mentalMap;
@synthesize identifier;
@synthesize conceptOneIdentifier;
@synthesize conceptTwoIdentifier;
@synthesize linkedMentalMap;
@synthesize linkerType;
@synthesize conceptOne;
@synthesize conceptTwo;

- (id)initWithHostMentalMap:(DARSMentalMap *)mentalMap {
	self = [super init];
	if (self) {
		self.mentalMap = mentalMap;
	}
	return self;
}

- (DARSConcept *)conceptOne {
	if (conceptOne == nil) {
		conceptOne = [self.mentalMap.brain conceptWithID:self.conceptOneIdentifier];
	}
	return conceptOne;
}

- (DARSConcept *)conceptTwo {
	if (conceptTwo == nil) {
		conceptTwo = [self.mentalMap.brain conceptWithID:self.conceptTwoIdentifier];
	}
	return conceptTwo;
}

@end

@implementation DARSNaturalLanguageRepresenter

@synthesize mentalMap = _mentalMap;
@synthesize identifier;
@synthesize text;
@synthesize partOfSpeech;
@synthesize linkedConcepts;

- (id)initWithHostMentalMap:(DARSMentalMap *)mentalMap {
	self = [super init];
	if (self) {
		self.mentalMap = mentalMap;
	}
	return self;
}

- (NSMutableArray *)linkedConcepts {
	if (linkedConcepts == nil) {
		linkedConcepts = [[NSMutableArray alloc] init];
		NSArray *concepts = [self.mentalMap.brain conceptsForWord:self.text];
		[linkedConcepts addObjectsFromArray:concepts];
	}
	return linkedConcepts;
}

@end

@implementation DARSMentalMap

@synthesize brain;
@synthesize mainConcepts;

- (id)initWithBrain:(DARSBrain *)brain {
	self = [super init];
	if (self) {
		mainConcepts = [[NSMutableArray alloc] init];
	}
	return self;
}

@end
