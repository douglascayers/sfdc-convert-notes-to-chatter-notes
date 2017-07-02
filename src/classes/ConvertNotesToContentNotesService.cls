/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Work horse that does the actual note to content note conversion.
 *
 * Uses 'without sharing' to ensure can perform SOQL queries on
 * existing ContentVersions and ContentDocumentLinks to know if
 * a Note has already been converted or not.
 */
public without sharing class ConvertNotesToContentNotesService {

    private ConvertNotesToContentNotesOptions options { get; set; }

    public ConvertNotesToContentNotesService() {
        this( new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesService( ConvertNotesToContentNotesOptions options ) {
        this.options = options;
    }

    /**
     * Each note record should have these fields populated:
     *  - Id
     *  - ParentId
     *  - OwnerId
     *  - Title
     *  - Body
     *  - IsPrivate
     *  - CreatedById
     *  - CreatedDate
     *  - LastModifiedById
     *  - LastModifiedDate
     */
    public List<ConversionResult> convert( List<Note> notes ) {

        // identify if any of these notes have already been converted
        Set<ID> alreadyConvertedNoteIds = filterAlreadyConvertedNoteIds( notes );

        List<ConversionResult> conversionResults = new List<ConversionResult>();
        List<ContentVersion> contentNotes = new List<ContentVersion>();

        for ( Note oldNote : notes ) {

            // skip if we've already converted this record before
            if ( alreadyConvertedNoteIds.contains( oldNote.id ) ) {
                continue;
            }

            // skip if we're not converting private notes
            if ( oldNote.IsPrivate && !this.options.convertPrivateNotes ) {
                continue;
            }

            // per Salesforce we must escape certain special characters
            // logic inspired by David Reed (http://www.ktema.org//2016/08/24/importing-notes-into-salesforce/)
            // https://help.salesforce.com/apex/HTViewSolution?id=000230867&language=en_US
            String noteBody = ( ( oldNote.body == null ) ? '' : oldNote.body )
                .escapeXml()
                .replace('\r\n', '<br>')
                .replace('\r', '<br>')
                .replace('\n', '<br>')
                .replace('&apos;', '&#39;')
            ;

            // content version cannot have a null or empty string body
            // so set to empty paragraph which will appear as blank note.
            // we do this after escaping the original note body otherwise
            // the <p> tag would get escaped, doh!
            if ( String.isBlank( noteBody ) ) {
                noteBody = '<p></p>';
            }

            // We set the owner of the new content note to be the
            // same as the note's creator because both fields
            // must have same value to insert the content note.
            // If they do not match then we get error:
            // "Documents in a user's private library must always be owned by that user."

            ContentVersion newNote = new ContentVersion(
                // data fields
                title = oldNote.title,
                versionData = Blob.valueOf( noteBody ),
                pathOnClient = oldNote.title + '.snote',
                // custom fields for history tracking and conversion purposes
                original_record_id__c = oldNote.id,
                original_record_parent_id__c = oldNote.parentId,
                original_record_owner_id__c = oldNote.ownerId,
                // audit fields
                ownerId = oldNote.ownerId, // system requirement, owner and creator must be the same
                createdById = oldNote.ownerId,
                createdDate = oldNote.createdDate,
                lastModifiedById = oldNote.lastModifiedById,
                lastModifiedDate = oldNote.lastModifiedDate
            );

            contentNotes.add( newNote );

        }

        if ( contentNotes.size() > 0 ) {

            Database.DMLOptions dmo = new Database.DMLOptions();
            dmo.optAllOrNone = false;

            List<Database.SaveResult> saveResults = Database.insert( contentNotes, dmo );

            for ( Integer i = 0; i < saveResults.size(); i++ ) {

                Database.SaveResult saveResult = saveResults[i];

                Note oldNote = notes[i];

                ConversionResult conversionResult = new ConversionResult();
                conversionResult.success = saveResult.isSuccess();
                conversionResult.contentNoteId = saveResult.getId();
                conversionResult.oldNote = oldNote;

                if ( !saveResult.isSuccess() ) {

                    List<String> messages = new List<String>();

                    for ( Database.Error err : saveResult.getErrors() ) {
                        messages.add( err.getMessage() );
                    }

                    conversionResult.message = String.join( messages, ' ' );

                }

                conversionResults.add( conversionResult );

            }

            postProcessConversionResults( conversionResults );

        }

        return conversionResults;
    }

    private void postProcessConversionResults( List<ConversionResult> conversionResults ) {

        Set<ID> contentNoteIds = new Set<ID>();

        for ( ConversionResult conversionResult : conversionResults ) {
            if ( String.isNotBlank( conversionResult.contentNoteId ) ) {
                contentNoteIds.add( conversionResult.contentNoteId );
            }
        }

        Map<ID, ContentVersion> contentVersionMap = new Map<ID, ContentVersion>([
            SELECT
                id,
                contentDocumentId
            FROM
                ContentVersion
            WHERE
                id IN :contentNoteIds
        ]);

        List<Note> notesToDelete = new List<Note>();
        List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();

        for ( ConversionResult conversionResult : conversionResults ) {

            if ( conversionResult.success ) {

                // should original note be deleted?
                if ( this.options.deleteNotesUponConversion ) {
                    notesToDelete.add( conversionResult.oldNote );
                }

                // should converted note be shared with parent?
                if ( !conversionResult.oldNote.isPrivate || ( conversionResult.oldNote.isPrivate && this.options.sharePrivateNotesWithParentRecord ) ) {

                    ContentVersion cv = contentVersionMap.get( conversionResult.contentNoteId );

                    if ( cv != null ) {

                        contentDocumentLinks.add( new ContentDocumentLink(
                            linkedEntityId = conversionResult.oldNote.parentId,
                            contentDocumentId = cv.contentDocumentId,
                            shareType = this.options.shareType,
                            visibility = this.options.visibility
                        ));

                    }

                }

            }

        }

        if ( notesToDelete.size() > 0 ) {
            delete notesToDelete;
        }

        if ( contentDocumentLinks.size() > 0 ) {
            insert contentDocumentLinks;
        }

    }

    /**
     * Given a list of notes then returns the sublist of those
     * that have already been converted.
     */
    public Set<ID> filterAlreadyConvertedNoteIds( List<Note> notes ) {

        Set<ID> filteredNoteIds = new Set<ID>();

        Set<ID> noteIds = new Set<ID>();
        Set<ID> parentIds = new Set<ID>();

        for ( Note note : notes ) {
            noteIds.add( note.id );
            parentIds.add( note.parentId );
        }

        for ( List<ContentDocumentLink> links : [
            SELECT
                contentDocument.latestPublishedVersion.original_record_id__c
            FROM
                ContentDocumentLink
            WHERE
                linkedEntityId IN :parentIds
                AND
                contentDocument.latestPublishedVersion.original_record_id__c IN :noteIds
        ]) {

            for ( ContentDocumentLink link : links ) {

                if ( link.contentDocument != null && link.contentDocument.latestPublishedVersion != null ) {

                    if ( noteIds.contains( link.contentDocument.latestPublishedVersion.original_record_id__c ) ) {
                        filteredNoteIds.add( link.contentDocument.latestPublishedVersion.original_record_id__c );
                    }

                }

            }

        }

        return filteredNoteIds;
    }

    public class ConversionResult {

        // true if note was converted; false otherwise
        public Boolean success { get; set; }

        // the original note to convert
        public Note oldNote { get; set; }

        // id of the converted note, if successful, null otherwise
        public ID contentNoteId { get; set; }

        // if not successful then the error message
        public String message { get; set; }

        public ConversionResult() {
            this.success = false;
            this.message = '';
        }

    }

}