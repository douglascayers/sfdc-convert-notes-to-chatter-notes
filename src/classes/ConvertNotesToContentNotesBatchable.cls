/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed for mass converting all notes in system or just those
 * belonging to specific parent records as indicated in the configuration options.
 *
 * Actual conversion for each batch execution is delegated to ConvertNotesToContentNotesService.
 */
global without sharing class ConvertNotesToContentNotesBatchable implements Database.Batchable<SObject>, Database.Stateful {

    @TestVisible
    private List<ConvertNotesToContentNotesService.ConversionResult> mockResults { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------

    @TestVisible
    private ConvertNotesToContentNotesOptions options { get; set; }

    @TestVisible
    private Integer conversionCount { get; set; } // the number of notes converted by this batchable

    global ConvertNotesToContentNotesBatchable() {
        this( new ConvertNotesToContentNotesOptions() );
    }

    // not exposed to subscriber orgs, want users to configure the custom setting
    public ConvertNotesToContentNotesBatchable( ConvertNotesToContentNotesOptions options ) {
        this.options = options;
        this.conversionCount = 0;
    }

    // ----------------------------------------------------------

    public Database.QueryLocator start( Database.BatchableContext context ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.start] Starting: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.start] Options: ' + this.options );

        if ( this.options == null || this.options.parentIds == null ) {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, title, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Note
                ORDER BY
                    parentId
            ]);

        } else {

            return Database.getQueryLocator([
                SELECT
                    id, ownerId, owner.isActive, parentId, title, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Note
                WHERE
                    parentId IN :this.options.parentIds
                ORDER BY
                    parentId
            ]);

        }

    }

    public void execute( Database.BatchableContext context, List<Note> notes ) {

        if ( this.conversionCount >= this.options.maxRecordsToConvert ) {
            System.debug( 'Reached max records to convert; aborting job: ' + context );
            System.abortJob( context.getJobId() );
            return;
        }

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( '[ConvertNotesToContentNotesBatchable.execute] Executing: ' + context );
            System.debug( '[ConvertNotesToContentNotesBatchable.execute] Options: ' + this.options );

            ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( this.options );

            List<ConvertNotesToContentNotesService.ConversionResult> results = service.convert( notes );

            if ( Test.isRunningTest() ) {

                if ( this.mockException != null ) {
                    throw this.mockException;
                }

                if ( this.mockResults != null ) {
                    results = mockResults;
                }

            }

            ConvertNotesToContentNotesLogger.log( context.getJobId(), results );

            for ( ConvertNotesToContentNotesService.ConversionResult result : results ) {
                if ( result.status == ConvertNotesToContentNotesService.ConversionResultStatus.CONVERTED ) {
                    this.conversionCount++;
                }
            }

        } catch ( Exception e ) {

            Database.rollback( sp );

            ConvertNotesToContentNotesLogger.log( context.getJobId(), e );

        }

    }

    public void finish( Database.BatchableContext context ) {

        System.debug( '[ConvertNotesToContentNotesBatchable.finish] Finishing: ' + context );
        System.debug( '[ConvertNotesToContentNotesBatchable.finish] Options: ' + this.options );

        ConvertNotesToContentNotesLogger.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

    }

}