/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesSettingsControllerTest {

    @isTest
    static void test_communities_enabled() {

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        Boolean isCommunitiesEnabled = controller.isCommunitiesEnabled;

        Test.stopTest();

        System.assertEquals( Schema.getGlobalDescribe().containsKey( 'Network' ), isCommunitiesEnabled );

    }

    @isTest
    static void test_save_new_settings() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        controller.settings = settings;
        controller.convertAndSharePrivateNotes = 'yes_convert_yes_share';

        controller.save();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Settings saved successfully' ) );

    }

    @isTest
    static void test_update_existing_settings() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        controller.settings = settings;

        controller.save();

        Test.stopTest();

        System.assertEquals( true, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Settings saved successfully' ) );

    }

    @isTest
    static void test_save_error() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        controller.settings = settings;

        // leave fields blank, cause validation errors
        controller.settings.visibility__c = null;

        controller.save();

        System.assertEquals( false, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Please answer all questions' ) );

        // fix validation error
        controller.settings.visibility__c = 'AllUsers';

        delete settings; // will cause exception on save because ID field is still populated on controller's reference

        controller.save();

        Test.stopTest();

        System.assertEquals( false, controller.success );

    }

    @isTest
    static void test_infer_convert_and_share_private_notes() {

        Convert_Notes_to_ContentNotes_Settings__c settings = new Convert_Notes_to_ContentNotes_Settings__c();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        Test.startTest();

        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;
        System.assertEquals( 'yes_convert_yes_share', controller.inferConvertAndSharePrivateNotes( settings ) );

        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = false;
        System.assertEquals( 'yes_convert_no_share', controller.inferConvertAndSharePrivateNotes( settings ) );

        settings.Convert_Private_Notes__c = false;
        settings.Share_Private_Notes__c = true; // ignored when convert is false
        System.assertEquals( 'no_convert_no_share', controller.inferConvertAndSharePrivateNotes( settings ) );

        settings.Convert_Private_Notes__c = false;
        settings.Share_Private_Notes__c = false; // ignored when convert is false
        System.assertEquals( 'no_convert_no_share', controller.inferConvertAndSharePrivateNotes( settings ) );

        Test.stopTest();

    }

    @isTest
    static void test_apply_convert_and_share_private_notes() {

        Convert_Notes_to_ContentNotes_Settings__c settings = new Convert_Notes_to_ContentNotes_Settings__c();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        Test.startTest();

        controller.applyConvertAndSharePrivateNotes( settings, 'yes_convert_yes_share' );
        System.assertEquals( true, settings.Convert_Private_Notes__c );
        System.assertEquals( true, settings.Share_Private_Notes__c );

        controller.applyConvertAndSharePrivateNotes( settings, 'yes_convert_no_share' );
        System.assertEquals( true, settings.Convert_Private_Notes__c );
        System.assertEquals( false, settings.Share_Private_Notes__c );

        controller.applyConvertAndSharePrivateNotes( settings, 'no_convert_yes_share' );
        System.assertEquals( false, settings.Convert_Private_Notes__c );
        System.assertEquals( false, settings.Share_Private_Notes__c ); // always false if convert is false

        controller.applyConvertAndSharePrivateNotes( settings, 'no_convert_no_share' );
        System.assertEquals( false, settings.Convert_Private_Notes__c );
        System.assertEquals( false, settings.Share_Private_Notes__c ); // always false if convert is false

        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;
        controller.applyConvertAndSharePrivateNotes( settings, 'gibberish' );
        System.assertEquals( false, settings.Convert_Private_Notes__c ); // always false for unrecognized values
        System.assertEquals( false, settings.Share_Private_Notes__c ); // always false for unrecognized values

        Test.stopTest();

    }

}