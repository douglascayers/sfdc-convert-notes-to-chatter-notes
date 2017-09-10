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
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Convert_Private_Notes__c = true;
        settings.Share_Private_Notes__c = true;

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

    @isTest
    static void test_inferConvertAndSharePrivateNotes() {

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        String yes_convert_yes_share = controller.inferConvertAndSharePrivateNotes( new Convert_Notes_to_ContentNotes_Settings__c(
            Convert_Private_Notes__c = true,
            Share_Private_Notes__c = true
        ));

        String yes_convert_no_share = controller.inferConvertAndSharePrivateNotes( new Convert_Notes_to_ContentNotes_Settings__c(
            Convert_Private_Notes__c = true,
            Share_Private_Notes__c = false
        ));

        String no_convert_no_share = controller.inferConvertAndSharePrivateNotes( new Convert_Notes_to_ContentNotes_Settings__c(
            Convert_Private_Notes__c = false,
            Share_Private_Notes__c = false
        ));

        Test.stopTest();

        System.assertEquals( 'yes_convert_yes_share', yes_convert_yes_share );
        System.assertEquals( 'yes_convert_no_share', yes_convert_no_share );
        System.assertEquals( 'no_convert_no_share', no_convert_no_share );

    }

    @isTest
    static void test_applyConvertAndSharePrivateNotes() {

        Test.startTest();

        ConvertNotesSettingsController controller = new ConvertNotesSettingsController();

        Convert_Notes_to_ContentNotes_Settings__c yes_convert_yes_share = new Convert_Notes_to_ContentNotes_Settings__c();
        controller.applyConvertAndSharePrivateNotes( yes_convert_yes_share, 'yes_convert_yes_share' );

        Convert_Notes_to_ContentNotes_Settings__c yes_convert_no_share = new Convert_Notes_to_ContentNotes_Settings__c();
        controller.applyConvertAndSharePrivateNotes( yes_convert_no_share, 'yes_convert_no_share' );

        Convert_Notes_to_ContentNotes_Settings__c no_convert_no_share = new Convert_Notes_to_ContentNotes_Settings__c();
        controller.applyConvertAndSharePrivateNotes( no_convert_no_share, 'no_convert_no_share' );

        Test.stopTest();

        System.assertEquals( true, yes_convert_yes_share.Convert_Private_Notes__c );
        System.assertEquals( true, yes_convert_yes_share.Share_Private_Notes__c );

        System.assertEquals( true, yes_convert_no_share.Convert_Private_Notes__c );
        System.assertEquals( false, yes_convert_no_share.Share_Private_Notes__c );

        System.assertEquals( false, no_convert_no_share.Convert_Private_Notes__c );
        System.assertEquals( false, no_convert_no_share.Share_Private_Notes__c );

    }

}