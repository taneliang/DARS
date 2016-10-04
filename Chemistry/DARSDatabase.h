//
//  DARSDatabase.h
//  DARS
//
//  Created by E-Liang Tan on 3/5/12.
//  Copyright (c) 2012 E-Liang Tan. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sqlite3.h>

enum {
	DARSBrainConceptLinkerTypeInstance,
	DARSBrainConceptLinkerTypeContains,
	DARSBrainConceptLinkerTypeMentalMap
};
typedef NSInteger DARSBrainConceptLinkerType;

@interface DARSDatabase : NSObject

- (id)initWithSQLite3DatabaseFilePath:(NSString *)filePath databaseAdaptor:(NSString *)dbAdaptorPath;
@property (strong, readonly) NSString *databaseName;
@property (strong, readonly) NSString *databaseFilePath;
@property (strong) NSDictionary *databaseInformation;
@property (strong) NSMutableArray *requiredVocabulary; // Does not include database data, only the table and column names

- (NSString *)naturalLanguageNameForColumn:(NSString *)columnName;
- (NSString *)columnNameForNaturalLanguageName:(NSString *)nlangName;

// Context provides the words around the value, which is at index vindex. Dist will provide the distance from vindex the algorithm had to search until
- (NSArray *)searchColumns:(NSArray *)columnNames inTable:(NSString *)tableName context:(NSArray *)context valueIndexInContext:(NSUInteger)vindex wordSearchDisplacementFromValueInContext:(NSInteger *)dist foundInColumn:(NSString **)column;

// Manual open close to remove the potential lag of opening and closing a database multiple times
@property sqlite3 *database; // Don't touch this outside of DARSDatabase
- (BOOL)openSQLDatabase;
- (BOOL)closeSQLDatabase;
- (NSArray *)executeSQLQuery:(NSString *)query; // Calls open and close automatically

@end

@class DARSBrain;
@class DARSMentalMap;
@class DARSNaturalLanguageRepresenter;

@interface DARSConcept : NSObject

- (id)initWithHostMentalMap:(DARSMentalMap *)mentalMap;
@property (assign) DARSMentalMap *mentalMap;

@property NSInteger identifier;
@property (strong) NSString *specialToken;
@property (nonatomic, strong) NSMutableArray *conceptLinkers;
@property (nonatomic, strong) NSMutableArray *naturalLanguageRepresenters;

@end

@interface DARSConceptLinker : NSObject

- (id)initWithHostMentalMap:(DARSMentalMap *)mentalMap;
@property (assign) DARSMentalMap *mentalMap;

@property NSInteger identifier;
@property NSInteger conceptOneIdentifier;
@property NSInteger conceptTwoIdentifier; // Anything ≤0 is an invalid identifier – No concept two
@property (strong) DARSMentalMap *linkedMentalMap; // Replaces conceptTwo if it exists.
@property DARSBrainConceptLinkerType linkerType;
@property (nonatomic, strong) DARSConcept *conceptOne;
@property (nonatomic, strong) DARSConcept *conceptTwo;

@end

@interface DARSNaturalLanguageRepresenter : NSObject

- (id)initWithHostMentalMap:(DARSMentalMap *)mentalMap;
@property (assign) DARSMentalMap *mentalMap;

@property NSInteger identifier;
@property (strong) NSString *text;
@property NSInteger partOfSpeech;
@property (nonatomic, strong) NSMutableArray *linkedConcepts;

@end

@interface DARSMentalMap : NSObject

- (id)initWithBrain:(DARSBrain *)brain;
@property (strong) DARSBrain *brain;
@property (strong, readonly) NSMutableArray *mainConcepts; // TODO: Implement event tracking, concept structure in sentence

@end

@interface DARSBrain : DARSDatabase

- (id)initWithVocabularyFilePath:(NSString *)filePath;

- (void)resetVocabulary:(NSString *)vocabularyDocumentFilePath;
- (DARSConcept *)conceptWithID:(NSInteger)identifier;
- (NSArray *)conceptsForWord:(NSString *)word;
- (NSArray *)representersWithText:(NSString *)text;
- (void)addWord:(NSString *)word forConcept:(NSInteger)concept; // If word exists, it will be linked
- (void)linkConcept:(NSInteger)conceptOne withConcept:(NSInteger)conceptTwo linkerType:(DARSBrainConceptLinkerType)linkerType;

- (void)assimilateDatabase:(DARSDatabase *)database;

@property (strong) DARSMentalMap *mentalMap;
- (void)emptyMentalMap;
- (void)loadMentalMapForInput:(NSString *)input;
- (NSString *)describeCurrentMentalMap;
- (void)findPathBetweenConcept:(DARSConcept *)conceptOne andConcept:(DARSConcept *)conceptTwo;

@end
