/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed for scheduling periodic job to perform batch conversion of notes.
 */
public with sharing class ConvertNotesToContentNotesSchedulable implements Schedulable {

    public Integer batchSize { get; set; }

    public ConvertNotesToContentNotesSchedulable() {
        this( 200 );
    }

    public ConvertNotesToContentNotesSchedulable( Integer batchSize ) {
        this.batchSize = batchSize;
    }

    public void execute( SchedulableContext context ) {

        SavePoint sp = Database.setSavePoint();

        DateTime startTime = DateTime.now();

        try {

            // we use the instance rather than org defaults here to support
            // overrides on a user or profile level
            Convert_Notes_to_ContentNotes_Settings__c settings = Convert_Notes_to_ContentNotes_Settings__c.getInstance();

            ConvertNotesToContentNotesOptions options = new ConvertNotesToContentNotesOptions( settings );

            System.debug( '[ConvertNotesToContentNotesSchedulable.execute] Executing: ' + context );
            System.debug( '[ConvertNotesToContentNotesSchedulable.execute] Options: ' + options );
            System.debug( '[ConvertNotesToContentNotesSchedulable.execute] Batch Size: ' + this.batchSize );

            ConvertNotesToContentNotesBatchable batchable = new ConvertNotesToContentNotesBatchable( options );

            Database.executeBatch( batchable, this.batchSize );

        } catch ( Exception e ) {

            Database.rollback( sp );

            ConvertNotesToContentNotesLogger.log( context.getTriggerId(), e );

        } finally {

            ConvertNotesToContentNotesLogger.sendApexExceptionEmailIfAnyErrorsSince( startTime );

        }

    }

}