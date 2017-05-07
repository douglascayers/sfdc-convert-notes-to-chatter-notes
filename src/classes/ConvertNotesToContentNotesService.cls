/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Work horse that does the actual note to content note conversion.
 */
public with sharing class ConvertNotesToContentNotesService {

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

        // noteId ==> conversion result
        // as a map for easy retrieval throughout the various steps doing the conversion
        // and creation of content document links to share new content note with parent record.
        // we update the message field on the result occasionally in subsequent steps
        Map<ID, ConversionResult> conversionResultsMap = new Map<ID, ConversionResult>();

        // identify if any of these notes have already been converted
        Set<ID> alreadyConvertedNoteIds = filterAlreadyConvertedNoteIds( notes );

        /*
         * Step 1
         * Convert Notes to ContentNotes
         */

        List<ConversionRequest> conversionRequests = new List<ConversionRequest>();
        List<ContentNote> contentNotes = new List<ContentNote>();

        for ( Note note : notes ) {

            // skip if we've already converted this record before
            if ( alreadyConvertedNoteIds.contains( note.id ) ) {
                continue;
            }

            // per Salesforce we must escape certain special characters
            // logic inspired by David Reed (http://www.ktema.org//2016/08/24/importing-notes-into-salesforce/)
            // https://help.salesforce.com/apex/HTViewSolution?id=000230867&language=en_US
            String noteBody = ( ( note.body == null ) ? '' : note.body )
                .escapeXml()
                .replace('\r\n', '<br>')
                .replace('\r', '<br>')
                .replace('\n', '<br>')
                .replace('&apos;', '&#39;')
            ;

            // We set the owner of the new content note to be the
            // same as the note's creator because both fields
            // must have same value to insert the content note.
            // If they do not match then we get error:
            // "Documents in a user's private library must always be owned by that user."

            ContentNote newNote = new ContentNote(
                // data fields
                title = note.title,
                content = Blob.valueOf( noteBody ),
                // audit fields
                ownerId = note.createdById, // system requirement, owner and creator must be the same
                createdById = note.createdById,
                createdDate = note.createdDate,
                lastModifiedById = note.lastModifiedById,
                lastModifiedDate = note.lastModifiedDate
            );

            contentNotes.add( newNote );

            conversionRequests.add( new ConversionRequest( note, newNote ) );

        }

        if ( contentNotes.size() > 0 ) {

            insert contentNotes;

            for ( ConversionRequest request : conversionRequests ) {

                ConversionResult result = new ConversionResult();
                result.success = true;
                result.contentNoteId = request.newNote.id;
                result.noteId = request.oldNote.id;

                conversionResultsMap.put( request.oldNote.id, result );

            }

            /*
             * Step 2
             * Requery ContentNotes to get latest published version id so that we can
             * know the generated content document id so that we can create
             * ContentDocumentLinks between the document and note's parent record and owner.
             * Doing so will share the new note so it's accessible by others.
             */

            Map<ID, ContentNote> contentNotesMap = new Map<ID, ContentNote>([
                SELECT
                    id,
                    ownerId,
                    latestPublishedVersionId,
                    latestPublishedVersion.contentDocumentId
                FROM
                    ContentNote
                WHERE
                    id IN :contentNotes
            ]);

            System.assertEquals( contentNotes.size(), contentNotesMap.size() );

            /*
             * Step 3
             * Create ContentDocumentLinks to share the new content
             * with the same parent record as the source note.
             * We also assign original owner to the note and stamp some tracking fields.
             */

            List<ContentDocumentLink> contentDocumentLinks = new List<ContentDocumentLink>();
            List<ContentVersion> contentVersions = new List<ContentVersion>();

            for ( ConversionRequest request : conversionRequests ) {

                ContentVersion cv = contentNotesMap.get( request.newNote.id ).latestPublishedVersion;

                // custom fields for history tracking and conversion purposes
                cv.original_record_id__c = request.oldNote.id;
                cv.original_record_parent_id__c = request.oldNote.parentId;
                cv.original_record_owner_id__c = request.oldNote.ownerId;

                contentVersions.add( cv );

                // should converted note be shared with parent?
                if ( !request.oldNote.isPrivate || ( request.oldNote.isPrivate && this.options.sharePrivateNotesWithParentRecord ) ) {

                    // share the new note with the same parent entity of the old note
                    // any user with visibility to this record has visibility to this note
                    contentDocumentLinks.add( new ContentDocumentLink(
                        linkedEntityId = request.oldNote.parentId,
                        contentDocumentId = cv.contentDocumentId,
                        shareType = this.options.shareType,
                        visibility = this.options.visibility
                    ));

                } else {

                    String message  = 'Not creating ContentDocumentLink to share ContentDocument (' + cv.contentDocumentId + ') with Parent Record (' + request.oldNote.parentId + ') because note record (' + request.oldNote.id + ') is private. ';
                           message += 'Either make note record not private or enable the [Share Private Notes?] option and convert again, or manually update the new document\'s sharing settings.';

                    conversionResultsMap.get( request.oldNote.id ).message += ' ' + message;

                }

            }

            // apply updates to content versions
            if ( contentVersions.size() > 0 ) {
                update contentVersions;
            }

            // create share links between new content note and original note parent entity
            if ( contentDocumentLinks.size() > 0 ) {
                insert contentDocumentLinks;
            }

            // lastly, delete the original notes that were successfully converted into files
            if ( this.options.deleteNotesUponConversion ) {

                List<Note> notesToDelete = new List<Note>();

                for ( ConversionRequest request : conversionRequests ) {
                    notesToDelete.add( request.oldNote );
                }

                delete notesToDelete;

            }

        }

        return conversionResultsMap.values();
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

    public class ConversionRequest {

        public Note oldNote { get; set; }

        public ContentNote newNote { get; set; }

        public ConversionRequest( Note oldNote, ContentNote newNote ) {
            this.oldNote = oldNote;
            this.newNote = newNote;
        }

    }

    public class ConversionResult {

        // true if note was converted; false otherwise
        public Boolean success { get; set; }

        // if of the note being converted, should always be populated
        public ID noteId { get; set; }

        // id of the converted note, if successful, null otherwise
        public ID contentNoteId { get; set; }

        // if not successful then the error message
        // even if success is true may include message if could not share note to intended parent entity
        public String message { get; set; }

        public ConversionResult() {
            this.success = false;
            this.message = '';
        }

    }

}