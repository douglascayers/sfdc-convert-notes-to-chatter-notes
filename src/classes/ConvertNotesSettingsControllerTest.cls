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
        settings.Share_Private_Notes__c = true;

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        controller.settings = settings;

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

}