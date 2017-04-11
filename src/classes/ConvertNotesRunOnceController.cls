/**
 * Developed by Doug Ayers (douglascayers.com)
 */
public with sharing class ConvertNotesRunOnceController {

    public ConvertNotesToContentNotesOptions options { get; set; }

    public String parentIdsCsv { get; set; }

    public Integer batchSize { get; set; }

    public String message { get; set; }

    public Boolean success { get; set; }

    public ConvertNotesRunOnceController() {
        this.options = new ConvertNotesToContentNotesOptions( Convert_Notes_to_ContentNotes_Settings__c.getOrgDefaults() );
        this.batchSize = 100;
        this.parentIdsCsv = '';
    }

    public void submitJob() {

        SavePoint sp = Database.setSavePoint();

        try {

            Set<ID> parentIds = new Set<ID>();

            for ( String parentId : this.parentIdsCsv.split( ',' ) ) {
                if ( String.isNotBlank( parentId ) ) {
                    parentIds.add( parentId.trim() );
                }
            }

            if ( !parentIds.isEmpty() ) {
                this.options.parentIds = parentIds;
            }

            System.debug( 'submitting one-time conversion job' );
            System.debug( 'options: ' + this.options );
            System.debug( 'batchSize: ' + this.batchSize );

            ConvertNotesToContentNotesBatchable job = new ConvertNotesToContentNotesBatchable( this.options );

            ID jobId = Database.executeBatch( job, this.batchSize );

            this.message = 'Conversion batch job submitted: ' + jobId;
            this.success = true;

        } catch ( Exception e ) {

            System.debug( LoggingLevel.ERROR, e.getMessage() + ' : ' + e.getStackTraceString() );

            Database.rollback( sp );

            this.message = e.getMessage();
            this.success = false;

        }

    }

}