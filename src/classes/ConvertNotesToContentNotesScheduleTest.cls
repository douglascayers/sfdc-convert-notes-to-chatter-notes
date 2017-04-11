/**
 * Developed by Doug Ayers (douglascayers.com)
 */
@isTest
private class ConvertNotesToContentNotesScheduleTest {

    @isTest
    static void test_schedulable() {

        Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        settings.Share_Type__c = 'I';
        settings.Visibility__c = 'AllUsers';
        settings.Convert_in_Near_Real_Time__c = false;
        settings.Delete_Note_Once_Converted__c = true;
        settings.Share_Private_Notes__c = true;

        upsert settings;

        Test.startTest();

        System.schedule( 'Conversion Job', '0 0 13 * * ?', new ConvertNotesToContentNotesSchedulable() );

        Test.stopTest();

        System.assertEquals( 0, [ SELECT count() FROM Convert_Notes_To_ContentNotes_Log__c ] );

    }

    @isTest
    static void test_errors() {

        ConvertNotesToContentNotesSchedulable job = new ConvertNotesToContentNotesSchedulable();

        job.batchSize = null; // will cause error

        Test.startTest();

        System.schedule( 'Conversion Job', '0 0 13 * * ?', job );

        Test.stopTest();

        System.assertEquals( 1, [ SELECT count() FROM Convert_Notes_To_ContentNotes_Log__c ] );

    }

}