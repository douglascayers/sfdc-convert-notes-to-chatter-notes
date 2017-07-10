/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesToContentNotesBatchableTest {

    @isTest
    static void test_real_time_trigger() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = true;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct1 = new Account(
            name = 'Test Account',
            ownerId = user1.id
        );

        insert acct1;

        Note note1 = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = acct1.id,
            ownerId = user1.id
        );

        Test.startTest();

        System.runAs( user1 ) {

            insert note1;

        }

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Note WHERE id = :note1.id ] );

        ContentDocumentLink cdl_note1 = [
            SELECT
                id,
                contentDocumentId,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
            linkedEntityId = :acct1.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :note1.id
        ];

        System.assertEquals( note1.id, cdl_note1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( note1.parentId, cdl_note1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( note1.ownerId, cdl_note1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_scope_conversion() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct1 = new Account(
            ownerId = user1.id,
            name = 'Test Account 1'
        );

        insert acct1;

        Account acct2 = new Account(
            ownerId = user2.id,
            name = 'Test Account 2'
        );

        insert acct2;

        Note note1 = new Note(
            title = 'Hello World 1.txt',
            body = 'Goodnight Moon',
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert note1;

        Note note2 = new Note(
            title = 'Hello World 2.txt',
            body = 'Goodnight Moon 2',
            parentId = acct2.id,
            ownerId = user2.id
        );

        insert note2;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );
        options.parentIds = new Set<ID>{ acct1.id };

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable( options );

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Note WHERE id = :note1.id ] );

        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct2.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Note WHERE id = :note2.id ] );

        ContentDocumentLink cdl_note1 = [
            SELECT
                id,
                contentDocumentId,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
            linkedEntityId = :acct1.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :note1.id
        ];

        System.assertEquals( note1.id, cdl_note1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( note1.parentId, cdl_note1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( note1.ownerId, cdl_note1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_preserve_original_owner() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct;

        Note note1 = new Note(
            title = 'Hello World 1.txt',
            body = 'Goodnight Moon',
            parentId = acct.id,
            ownerId = user1.id
        );

        insert note1;

        Note note2 = new Note(
            title = 'Hello World 2.txt',
            body = 'Goodnight Moon 2',
            parentId = acct.id,
            ownerId = user2.id
        );

        insert note2;

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        ContentDocumentLink cdl_note1 = [
            SELECT
                id,
                contentDocument.fileType,
                contentDocumentId,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
                linkedEntityId = :acct.id
                AND
                contentDocument.latestPublishedVersion.original_record_id__c = :note1.id
        ];

        System.assertEquals( 'SNOTE', cdl_note1.contentDocument.fileType );
        System.assertEquals( note1.id, cdl_note1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( note1.parentId, cdl_note1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( note1.ownerId, cdl_note1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

        ContentDocumentLink cdl_note2 = [
            SELECT
                id,
                contentDocumentId,
                contentDocument.fileType,
                contentDocument.latestPublishedVersion.original_record_id__c,
                contentDocument.latestPublishedVersion.original_record_parent_id__c,
                contentDocument.latestPublishedVersion.original_record_owner_id__c
            FROM
                ContentDocumentLink
            WHERE
            linkedEntityId = :acct.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :note2.id
        ];

        System.assertEquals( 'SNOTE', cdl_note2.contentDocument.fileType );
        System.assertEquals( note2.id, cdl_note2.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( note2.parentId, cdl_note2.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( note2.ownerId, cdl_note2.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_preserve_original_inactive_owner() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = ConvertNotesToContentNotesTestFactory.newUser( p.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account acct = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert acct;

        System.runAs( user1 ) {

            Note note1 = new Note(
                title = 'Hello World 1.txt',
                body = 'Goodnight Moon',
                parentId = acct.id,
                ownerId = user1.id
            );

            insert note1;

        }

        System.runAs( user2 ) {

            Note note2 = new Note(
                title = 'Hello World 2.txt',
                body = 'Goodnight Moon 2',
                parentId = acct.id,
                ownerId = user2.id
            );

            insert note2;

        }

        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user2.isActive = false;
            update user2;

        }

        Test.startTest();

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 2, [ SELECT count() FROM Convert_Notes_to_ContentNotes_Log__c ] );
        System.assertEquals( 2, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct.id ] );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct.id AND contentDocument.ownerId = :user1.id ] );
        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct.id AND contentDocument.ownerId = :user2.id ] );
        System.assertEquals( 0, [ SELECT count() FROM Note ] );

    }

    @isTest
    static void test_conversion_error() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Account acct = new Account(
            name = 'Test Account'
        );

        insert acct;

        Note note = new Note(
            title = 'Hello World 1',
            body = 'Hello World 1',
            parentId = acct.id
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesService.ConversionResult mockResult = new ConvertNotesToContentNotesService.ConversionResult();
        mockResult.status = ConvertNotesToContentNotesService.ConversionResultStatus.ERROR;
        mockResult.message = 'Mock Error Result';

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable( options );

        batchable.mockResults = new List<ConvertNotesToContentNotesService.ConversionResult>{ mockResult };

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM Convert_Notes_to_ContentNotes_Log__c WHERE Status__c = 'ERROR' ] );

    }

    @isTest
    static void test_conversion_exception() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Account acct = new Account(
            name = 'Test Account'
        );

        insert acct;

        Note note = new Note(
            title = 'Hello World 1',
            body = 'Hello World 1',
            parentId = acct.id
        );

        insert note;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable( options );

        batchable.mockException = new System.NullPointerException();

        Database.executeBatch( batchable, 100 );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM Convert_Notes_to_ContentNotes_Log__c WHERE Status__c = 'ERROR' ] );

    }

}