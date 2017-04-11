/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertNotesInstallHandler implements InstallHandler {

    public void onInstall( InstallContext context ) {

        try {

            Boolean isNew = ( context.previousVersion() == null );

            // for new installs then populate the custom setting
            if ( isNew ) {

                Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults();

                if ( String.isBlank( settings.id ) ) {

                    settings.Share_Type__c = 'I';
                    settings.Visibility__c = 'AllUsers';
                    settings.Convert_in_Near_Real_Time__c = false;
                    settings.Delete_Note_Once_Converted__c = false;
                    settings.Share_Private_Notes__c = false;

                    insert settings;

                }

            }

        } catch ( Exception e ) {

            // not really interested in the error
            // this is just a convenience to pre-populate custom setting

        }

    }

}