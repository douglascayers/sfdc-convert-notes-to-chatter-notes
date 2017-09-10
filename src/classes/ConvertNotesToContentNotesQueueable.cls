/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Designed to be invoked within a trigger or some other scenario where you
 * need exactly one batch of records (up to 200 records) to be converted to ContentNotes.
 *
 * Actual conversion for the execution is delegated to ConvertNotesToContentNotesService.
 */
global with sharing class ConvertNotesToContentNotesQueueable implements System.Queueable {

    @TestVisible
    private List<ConvertNotesToContentNotesService.ConversionResult> mockResults { get; set; }

    @TestVisible
    private Exception mockException { get; set; }

    // ----------------------------------------------------------------------

    private ConvertNotesToContentNotesOptions options { get; set; }

    private Set<ID> noteIds { get; set; }

    // if context user is a community user then we
    // need to pass on the network id to assign to ContentVersion
    private ID networkId { get; set; }

    global ConvertNotesToContentNotesQueueable( Set<ID> noteIds ) {
        this( noteIds, new ConvertNotesToContentNotesOptions() );
    }

    // not exposed to subscriber orgs, want users to configure the custom setting
    public ConvertNotesToContentNotesQueueable( Set<ID> noteIds, ConvertNotesToContentNotesOptions options ) {
        this( noteIds, options, Network.getNetworkId() );
    }

    // not exposed to subscriber orgs, want users to configure the custom setting
    public ConvertNotesToContentNotesQueueable( Set<ID> noteIds, ConvertNotesToContentNotesOptions options, ID networkId ) {
        this.noteIds = noteIds;
        this.options = options;
        this.networkId = networkId;
    }

    // ----------------------------------------------------------------------

    public void execute( QueueableContext context ) {

        SavePoint sp = Database.setSavePoint();

        try {

            System.debug( '[ConvertNotesToContentNotesQueueable.execute] Executing: ' + context );

            List<Note> notes = new List<Note>([
                SELECT
                    id, parentId, ownerId, title, body, isPrivate,
                    createdById, createdDate, lastModifiedById, lastModifiedDate
                FROM
                    Note
                WHERE
                    id IN :this.noteIds
                ORDER BY
                    parentId
            ]);

            ConvertNotesToContentNotesService service = new ConvertNotesToContentNotesService( this.options, this.networkId );

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

        } catch ( Exception e ) {

            Database.rollback( sp );

            ConvertNotesToContentNotesLogger.log( context.getJobId(), e );

        } finally {

            ConvertNotesToContentNotesLogger.sendApexExceptionEmailIfAnyErrorsSince( context.getJobId() );

        }

    }

}