/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Enqueues a job to convert the notes into enhanced notes.
 * Note, some triggers aren't fired for actions performed in Case Feed:
 * https://success.salesforce.com/issues_view?id=a1p300000008YTEAA2
 */
trigger ConvertNotesToContentNotesTrigger on Note ( after insert ) {

    // we use the instance rather than org defaults here to support
    // overrides on a user or profile level
    Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getInstance();

    if ( settings.convert_in_near_real_time__c ) {

        ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

        ConvertNotesToContentNotesQueueable queueable = new ConvertNotesToContentNotesQueueable( Trigger.newMap.keySet(), options );

        System.enqueueJob( queueable );

    }

}