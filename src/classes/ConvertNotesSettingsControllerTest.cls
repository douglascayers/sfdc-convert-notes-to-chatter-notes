/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesSettingsControllerTest {

    @isTest
    static void test_save_new_settings() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;

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
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;

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
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;

        upsert settings;

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        controller.settings = settings;

        controller.mockIsFormValid = false;

        controller.save();

        System.assertEquals( false, controller.success );
        System.assert( controller.message.containsIgnoreCase( 'Please answer all questions' ) );

        controller.mockIsFormValid = true;
        controller.mockException = new System.NullPointerException();

        controller.save();

        Test.stopTest();

        System.assertEquals( false, controller.success );

    }

}