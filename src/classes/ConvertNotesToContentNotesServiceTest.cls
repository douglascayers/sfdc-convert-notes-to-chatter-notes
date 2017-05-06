/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesToContentNotesServiceTest {

    @isTest
    static void test_partner_community_users() {

        try {

            Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
            settings.Share_Type__c = 'I';
            settings.Visibility__c = 'AllUsers';
            settings.Convert_in_Near_Real_Time__c = true;
            settings.Delete_Note_Once_Converted__c = false;
            settings.Share_Private_Notes__c = true;

            upsert settings;

            UserRole r1 = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

            Profile p1 = [ SELECT id FROM Profile WHERE name = 'Standard User' ];
            Profile p2 = [ SELECT id FROM Profile WHERE name = 'Partner Community User' ];

            User user1, user2;

            // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
            System.runAs( new User( id = UserInfo.getUserId() ) ) {

                user1 = newUser( p1.id, r1.id, 'Alpha', 'User 1', 'user_1@example.com' );

                insert user1;

            }

            Account acct = new Account(
                ownerId = user1.id,
                name = 'Community Account'
            );

            insert acct;

            Contact cont = new Contact(
                accountId = acct.id,
                firstName = 'Beta',
                lastName = 'User 2'
            );

            insert cont;

            // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
            System.runAs( new User( id = UserInfo.getUserId() ) ) {

                user2 = newUser( p2.id, null, 'Beta',  'User 2', 'user_2@example.com' );

                user2.contactId = cont.id;

                insert user2;

            }

            Test.startTest();

            System.runAs( user2 ) {

                Note note1 = new Note(
                    title = 'Hello World.txt',
                    body = 'Goodnight Moon',
                    parentId = acct.id,
                    ownerId = user2.id
                );

                insert note1;

                Note note2 = new Note(
                    title = 'Hello World.txt',
                    body = 'Goodnight Moon',
                    parentId = cont.id,
                    ownerId = user2.id
                );

                insert note2;

            }

            Test.stopTest();

            // must do assert after stopping test because of async code
            System.assertEquals( 2, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId IN ( :acct.id, :cont.id ) ] );

            System.runAs( user2 ) {

                List<Note> notes = [
                    SELECT
                        id, parentId, ownerId, title, body, isPrivate,
                        createdById, createdDate, lastModifiedById, lastModifiedDate
                    FROM
                        Note
                ];

                ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService();

                // we should get back both note ids as they've already been converted
                Set<ID> convertedNoteIds = service.filterAlreadyConvertedNoteIds( notes );
                System.assertEquals( 2, convertedNoteIds.size() );

                // since both notes have been converted then no other conversion should occur
                List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( notes );
                System.assertEquals( 0, results.size() );
                System.assertEquals( 2, [ SELECT count() FROM ContentDocumentLink WHERE linkedEntityId IN ( :acct.id, :cont.id ) ] );

            }

        } catch ( Exception e ) {

            // if org does not have communities enabled
            // then don't worry about this test
            if ( !e.getMessage().containsIgnoreCase( 'PORTAL_NO_ACCESS' ) ) {
                throw e;
            }

        }

    }

    @isTest
    static void test_special_characters() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note plainNote = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        Note specialTitleNote = new Note(
            title = 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        Note specialBodyNote = new Note(
            title = 'Hello World.txt',
            body = 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >',
            parentId = account.id,
            ownerId = user1.id
        );

        Note specialTitleAndBodyNote = new Note(
            title = 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >',
            body = 'Hello ! @ # $ % ^ & * ( )  + = - _ \' \" , . ? / \\ [ ] { } | ` ~ < >',
            parentId = account.id,
            ownerId = user1.id
        );

        Note htmlBodyNote = new Note(
            title = 'Hello World.html',
            body = '<b>bold</b> <u>underline</u> <i>italic</i> <ul><li>list item</li></ul> <ol><li>list item</li></ol> <a href="www.salesforce.com">link</a> <div></div> <p></p> &nbsp; <span style="color:red">text</span> <img src="image.png"/>',
            parentId = account.id,
            ownerId = user1.id
        );

        Note githubIssue8 = new Note(
            title = 'Meeting Agenda 2016-06-16 agenda.pdf',
            body = 'Meeting Agenda 2016-06-16 agenda.pdf',
            parentId = account.id,
            ownerId = user1.id
        );

        Note[] notes = new Note[] { plainNote, specialTitleNote, specialBodyNote, specialTitleAndBodyNote, htmlBodyNote, githubIssue8 };

        insert notes;

        notes = [
            SELECT
                id, parentId, ownerId, title, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Note
            WHERE
                id = :notes
        ];

        Test.startTest();

        List<ConvertNotesToContentNotesService.ConversionResult> results = null;

        System.runAs( user1 ) {

            ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService();

            results = service.convert( notes );

        }

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

    }

    @isTest
    static void test_convert_real_time() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = true;
        settings.Delete_Note_Once_Converted__c = false;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        Test.startTest();

        insert note;

        Test.stopTest();

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

        List<Note> notes = new List<Note>([ SELECT id FROM Note WHERE id = :note.id ]);
        System.assertEquals( 1, notes.size() );

    }

    @isTest
    static void test_no_delete() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = false;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        insert note;

        note = [
            SELECT
                id, parentId, ownerId, title, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Note
            WHERE
                id = :note.id
        ];

        Test.startTest();

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService();

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( new Note[]{ note } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

        List<Note> notes = new List<Note>([ SELECT id FROM Note WHERE id = :note.id ]);
        System.assertEquals( 1, notes.size() );

    }

    @isTest
    static void test_yes_delete() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        insert note;

        note = [
            SELECT
                id, parentId, ownerId, title, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Note
            WHERE
                id = :note.id
        ];

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();
        options.deleteNotesUponConversion = true;

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( new Note[]{ note } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        ContentNote cn = [ SELECT id, latestPublishedVersionId FROM ContentNote WHERE latestPublishedVersionId = :cv.id ];
        System.assert( cn != null );

        List<Note> notes = new List<Note>([ SELECT id FROM Note WHERE id = :note.id ]);
        System.assertEquals( 0, notes.size() );

    }

    @isTest
    static void test_no_share_private_notes_with_parent_record() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = false;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id,
            isPrivate = true
        );

        insert note;

        note = [
            SELECT
                id, parentId, ownerId, title, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Note
            WHERE
                id = :note.id
        ];

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();
        options.sharePrivateNotesWithParentRecord = false;

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( new Note[]{ note } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        List<ContentDocumentLink> cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assertEquals( 0, cdl.size() );

    }

    @isTest
    static void test_yes_share_private_notes_with_parent_record() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id,
            isPrivate = true
        );

        insert note;

        note = [
            SELECT
                id, parentId, ownerId, title, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Note
            WHERE
                id = :note.id
        ];

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();
        options.sharePrivateNotesWithParentRecord = true;

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( new Note[]{ note } );

        Test.stopTest();

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

        ContentVersion cv = [ SELECT id, contentDocumentId FROM ContentVersion WHERE original_record_id__c = :note.id AND isLatest = true ];
        System.assert( cv != null );

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId FROM ContentDocumentLink WHERE contentDocumentId = :cv.contentDocumentId AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

    }

    @isTest
    static void test_no_duplicates() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = false;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        UserRole role = [ SELECT id FROM UserRole WHERE parentRoleId = null AND portalType = 'None' LIMIT 1 ];

        Profile p = [ SELECT id FROM Profile WHERE name = 'Standard User' ];

        User user1, user2;

        // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_tools_runas.htm
        System.runAs( new User( id = UserInfo.getUserId() ) ) {

            user1 = newUser( p.id, role.id, 'Alpha', 'User 1', 'user_1@example.com' );
            user2 = newUser( p.id, role.id, 'Beta',  'User 2', 'user_2@example.com' );

            insert new List<User>{ user1, user2 };

        }

        Account account = new Account(
            ownerId = user1.id,
            name = 'Test Account'
        );

        insert account;

        Note note = new Note(
            title = 'Hello World.txt',
            body = 'Goodnight Moon',
            parentId = account.id,
            ownerId = user1.id
        );

        System.runAs( user1 ) {

            insert note;

        }

        note = [
            SELECT
                id, parentId, ownerId, title, body, isPrivate,
                createdById, createdDate, lastModifiedById, lastModifiedDate
            FROM
                Note
            WHERE
                id = :note.id
        ];

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions();

        ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( options );

        List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( new Note[]{ note } );

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

        ContentDocumentLink cdl = [ SELECT id, linkedEntityId, contentDocument.latestPublishedVersion.ownerId FROM ContentDocumentLink WHERE contentDocument.latestPublishedVersion.original_record_id__c = :note.id AND linkedEntityId = :account.id ];
        System.assert( cdl != null );

        // convert again, expect no duplicate file created

        results = service.convert( new Note[]{ note } );

        System.assertNotEquals( null, results );

        for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
            System.debug( result );
            System.assertEquals( true, result.success, result.message );
        }

        System.assertEquals( 1, [ SELECT count() FROM ContentDocumentLink WHERE contentDocument.latestPublishedVersion.original_record_id__c = :note.id AND linkedEntityId = :account.id ] );
        System.assertEquals( 1, [ SELECT count() FROM Note WHERE id = :note.id ] );

        Test.stopTest();

    }

    @isTest
    static void test_init_options_from_settings() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = true;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Test.startTest();

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        Test.stopTest();

        System.assertEquals( settings.Share_Type__c, options.shareType );
        System.assertEquals( settings.Visibility__c, options.visibility );
        System.assertEquals( settings.Delete_Note_Once_Converted__c, options.deleteNotesUponConversion );
        System.assertEquals( settings.Share_Private_Notes__c, options.sharePrivateNotesWithParentRecord );

    }

    private static User newUser( ID profileId, ID roleId, String firstName, String lastName, String email ) {
        Integer rand = Math.round( Math.random() * 1000 );
        return new User(
            isActive = true,
            profileId = profileId,
            userRoleId = roleId,
            alias = firstName.substring(0,1) + lastName.substring(1,5),
            firstName = firstName,
            lastName = lastName,
            email = email,
            username = rand + email,
            emailEncodingKey = 'UTF-8',
            languageLocaleKey = 'en_US',
            localeSidKey = 'en_US',
            timeZoneSidKey = 'America/Chicago'
        );
    }

}