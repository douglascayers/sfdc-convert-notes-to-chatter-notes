/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesInstallHandlerTest {

    @isTest
    static void test_new_install() {

        Test.startTest();

        Test.testInstall( new ConvertNotesInstallHandler(), null );

        Test.stopTest();

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();

        System.assert( String.isNotBlank( settings.id ), 'id should not be blank' );
        System.assertEquals( false, settings.Convert_in_Near_Real_Time__c );
        System.assertEquals( false, settings.Delete_Note_Once_Converted__c );
        System.assertEquals( false, settings.Convert_Private_Notes__c );
        System.assertEquals( false, settings.Share_Private_Notes__c );

    }

    @isTest
    static void test_upgrade() {

        Convert_Notes_to_ContentNotes_Settings__c preSettings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        preSettings.Convert_in_Near_Real_Time__c = true;
        preSettings.Delete_Note_Once_Converted__c = true;
        preSettings.Convert_Private_Notes__c = true;
        preSettings.Share_Private_Notes__c = true;

        upsert preSettings;

        Test.startTest();

        Test.testInstall( new ConvertNotesInstallHandler(), new Version( 1, 0 ) );

        Test.stopTest();

        Convert_Notes_to_ContentNotes_Settings__c postSettings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();

        System.assertEquals( preSettings.id, postSettings.id );
        System.assertEquals( preSettings.Convert_in_Near_Real_Time__c, postSettings.Convert_in_Near_Real_Time__c );
        System.assertEquals( preSettings.Delete_Note_Once_Converted__c, postSettings.Delete_Note_Once_Converted__c );
        System.assertEquals( preSettings.Convert_Private_Notes__c, postSettings.Convert_Private_Notes__c );
        System.assertEquals( preSettings.Share_Private_Notes__c, postSettings.Share_Private_Notes__c );

    }

}