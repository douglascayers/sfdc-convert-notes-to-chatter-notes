/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertNotesSettingsController {

    public Convert_Notes_to_ContentNotes_Settings__c settings { get; set; }

    // this option combines two setting fields for whether or not to
    // actually convert private notes, and if yes, how to share them.
    // based on the submitted value then settings.Convert_Private_Notes__c and settings.Share_Private_Notes__c
    // will be assigned their true/false values.
    // this allows us to have one radio button on the vf page even though stored in two fields in database
    public String convertAndSharePrivateNotes { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public Boolean isCommunitiesEnabled {
        get {
            return Schema.getGlobalDescribe().containsKey( 'Network' );
        }
    }

    public ConvertNotesSettingsController() {

        this.settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();
        this.convertAndSharePrivateNotes = inferConvertAndSharePrivateNotes( this.settings );

    }

    public void save() {

        SavePoint sp = Database.setSavePoint();

        ID originalId = this.settings.id;

        try {

            applyConvertAndSharePrivateNotes( this.settings, this.convertAndSharePrivateNotes );

            if ( settings.Delete_Note_Once_Converted__c == null ||
                 settings.Convert_Private_Notes__c == null ||
                 settings.Share_Private_Notes__c == null ||
                 settings.Share_Type__c == null ||
                 settings.Visibility__c == null
            ) {

                this.success = false;
                this.message = 'Please answer all questions to configure conversion options.';

            } else {

                upsert this.settings;

                // refresh any values set on insert
                this.settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();

                this.message = 'Settings saved successfully!';
                this.success = true;

            }

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            Database.rollback( sp );

            this.settings.id = originalId;

            this.message = e.getMessage();
            this.success = false;

        }

    }

    /**
     * Based on Convert_Private_Notes__c and Share_Private_Notes__c will return one of three values:
     *  1. yes_convert_yes_share
     *  2. yes_convert_no_share
     *  3. no_convert_no_share
     */
    @TestVisible
    private String inferConvertAndSharePrivateNotes( Convert_Notes_to_ContentNotes_Settings__c settings ) {

        String value = 'no_convert_no_share';

        if ( settings.Convert_Private_Notes__c ) {
            if ( settings.Share_Private_Notes__c ) {
                value = 'yes_convert_yes_share';
            } else {
                value = 'yes_convert_no_share';
            }
        }

        return value;
    }

    /**
     * Based on the value of the 'convertAndSharePrivateNotes' string this method
     * assigns true/false to the setting's Convert_Private_Notes__c and Share_Private_Notes__c fields.
     */
    @TestVisible
    private void applyConvertAndSharePrivateNotes( Convert_Notes_to_ContentNotes_Settings__c settings, String convertAndSharePrivateNotes ) {

        if ( convertAndSharePrivateNotes == 'yes_convert_yes_share' ) {
            settings.Convert_Private_Notes__c = true;
            settings.Share_Private_Notes__c = true;
        } else if ( convertAndSharePrivateNotes == 'yes_convert_no_share' ) {
            settings.Convert_Private_Notes__c = true;
            settings.Share_Private_Notes__c = false;
        } else {
            settings.Convert_Private_Notes__c = false;
            settings.Share_Private_Notes__c = false;
        }

    }

}