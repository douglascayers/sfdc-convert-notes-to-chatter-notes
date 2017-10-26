/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesToContentNotesQueueableTest {

    @isTest
    static void test_queueable_with_options() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;

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
            name = 'Test Account'
        );

        insert acct1;

        Note note1 = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert note1;

        Test.startTest();

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            new Set<ID>{ note1.id },
            new ConvertNotesToContentNotesOptions( settings )
        );

        System.enqueueJob( queueable );

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
                contentDocument.fileType,
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

        System.assertEquals( 'SNOTE', cdl_note1.contentDocument.fileType );
        System.assertEquals( note1.id, cdl_note1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( note1.parentId, cdl_note1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( note1.ownerId, cdl_note1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_queueable_without_options() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = false;

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
            name = 'Test Account'
        );

        insert acct1;

        Note note1 = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = acct1.id,
            ownerId = user1.id
        );

        insert note1;

        Test.startTest();

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            new Set<ID>{ note1.id }
        );

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Note WHERE id = :note1.id ] );

        ContentDocumentLink cdl_note1 = [
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
            linkedEntityId = :acct1.id
            AND
            contentDocument.latestPublishedVersion.original_record_id__c = :note1.id
        ];

        System.assertEquals( 'SNOTE', cdl_note1.contentDocument.fileType );
        System.assertEquals( note1.id, cdl_note1.contentDocument.latestPublishedVersion.original_record_id__c );
        System.assertEquals( note1.parentId, cdl_note1.contentDocument.latestPublishedVersion.original_record_parent_id__c );
        System.assertEquals( note1.ownerId, cdl_note1.contentDocument.latestPublishedVersion.original_record_owner_id__c );

    }

    @isTest
    static void test_conversion_error() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account'
        );

        insert acct1;

        Note note1 = new Note(
            title = 'Hello World 1',
            body = 'Hello World 1',
            parentId = acct1.id
        );

        insert note1;

        Test.startTest();

        ConvertNotesToContentNotesService.ConversionResult mockResult = new ConvertNotesToContentNotesService.ConversionResult();
        mockResult.status = ConvertNotesToContentNotesService.ConversionResultStatus.ERROR;
        mockResult.message = 'Mock Error Result';
        mockResult.oldNote = note1;

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            new Set<ID>{ note1.id }
        );

        queueable.mockResults = new List<ConvertNotesToContentNotesService.ConversionResult>{ mockResult };

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 1, [ SELECT count() FROM Convert_Notes_to_ContentNotes_Log__c WHERE old_note_id__c = :note1.id AND status__c = 'ERROR' ] );

    }

    @isTest
    static void test_conversion_exception() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;

        upsert settings;

        Account acct1 = new Account(
            name = 'Test Account'
        );

        insert acct1;

        Note note1 = new Note(
            title = 'Hello World 1',
            body = 'Hello World 1',
            parentId = acct1.id
        );

        insert note1;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable(
            new Set<ID>{ note1.id }
        );

        queueable.mockException = new System.NullPointerException();

        System.enqueueJob( queueable );

        Test.stopTest();

        for ( Convert_Notes_to_ContentNotes_Log__c log : [ SELECT Status__c, Old_Note_ID__c, New_Note_ID__c, Summary__c, Detail__c FROM Convert_Notes_to_ContentNotes_Log__c ] ) {
            System.debug( log );
        }

        System.assertEquals( 0, [ SELECT count() FROM ContentVersion WHERE original_record_id__c = :note1.id ] );
        System.assertEquals( 0, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId = :acct1.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Convert_Notes_to_ContentNotes_Log__c WHERE status__c = 'ERROR' ] );

    }

}