# DARS — Database Access and Retrieval System

The Database Access and Retrieval System (DARS) is a macOS application that can perform natural language lookups on any SQLite database. A video of it in action is available here: <https://youtu.be/yM43Q41spZA>

DARS was an experimental project written in 2012 and is no longer being updated.

## Usage

### Building and Installation

1. Download and unzip the project.
2. Open Chemistry/DARS.m, and change the file path to point to vocabulary.db, which was included in the zip file. vocabulary.db is empty, and can easily be created using the command `sqlite3 test.db "" `
3. Open the Xcode project.
4. Build and run.

### Creating Database Adaptors

Adaptors are required to give DARS the natural language names of the tables and columns in your database. They're JSON files containing a dictionary.

1. Create JSON file for the adaptor, and create a dictionary.
2. Use the code below as a template:

    ```JSON
    {
        "DARS_file_contents": "DARS.database.adaptor",
        "database_format": "sqlite3",
        "database_name": "<db name>",
        "tables":
        [
         {
         "table_name": "<db table name>",
         "table_natural_language_name": "<table name as you would say it>",
         "table_contents_plural": "<e.g. elements>",
         "table_contents_singular": "<e.g. element>",
         "columns":
         [
          {
          "column_name": "<column name as it is in the db>",
          "column_natural_language_name": "<column name as you would say it>",
          "column_contents_singular": "<e.g. proton number>",
          "column_contents_plural": "<e.g. proton numbers>",
          },
          // ... more columns ...
         ]
         },
         // ... more tables ...
        ]
    }
    ```

You may refer to the chemistry_db.js adaptor for chemistry.db.

### Attaching and Detaching Databases

1. Run command `attach database (<full path to db>) (<full path to adaptor>)`.
2. Perform queries.
3. Run command `detach database <database_name>` if you wish to detach it.
