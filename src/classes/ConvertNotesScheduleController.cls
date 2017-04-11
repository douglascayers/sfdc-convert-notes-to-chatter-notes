/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertNotesScheduleController {

    public Convert_Notes_to_ContentNotes_Settings__c settings { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertNotesScheduleController() {

        this.settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();

    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            upsert this.settings;

            this.message = 'Settings saved successfully!';
            this.success = true;

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            Database.rollback( sp );

            this.settings.id = originalId;

            this.message = e.getMessage();
            this.success = false;

        }

    }

}