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

    // if context user is a community user then we
    // need to pass on the network id to assign to ContentVersion
    private ID networkId { get; set; }

    public ConvertNotesToContentNotesService() {
        this( new ConvertNotesToContentNotesOptions() );
    }

    public ConvertNotesToContentNotesService( ConvertNotesToContentNotesOptions options ) {
        this.options = options;
    }

    public ConvertNotesToContentNotesService( ConvertNotesToContentNotesOptions options, ID networkId ) {
        this.options = options;
        this.networkId = networkId;
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
    public List<ConversionResult> convert( List<Note> oldNotes ) {

        // determine if communities are enabled and if so then we will need
        // to assign the network id field when inserting the content versions
        // otherwise error "INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY" occurs
        // if community user creates a note and it tries to get converted
        Boolean communitiesEnabled = ContentVersion.sObjectType.getDescribe().fields.getMap().containsKey( 'NetworkId' );

        // identify if any of these notes have already been converted
        Map<ID, ID> alreadyConvertedNoteIdsMap = getAlreadyConvertedNoteIdsMap( oldNotes );

        Map<ID, Note> oldNotesMap = new Map<ID, Note>( oldNotes );

        // map of old note id to conversion result
        Map<ID, ConversionResult> conversionResultsMap = new Map<ID, ConversionResult>();

        // the new notes to try and save
        List<ContentVersion> newNoteVersions = new List<ContentVersion>();

        for ( Note oldNote : oldNotes ) {

            // skip if we've already converted this record before
            if ( alreadyConvertedNoteIdsMap.containsKey( oldNote.id ) ) {

                ConversionResult conversionResult = new ConversionResult();
                conversionResult.status = ConversionResultStatus.SKIPPED;
                conversionResult.oldNote = oldNote;
                conversionResult.contentNoteId = alreadyConvertedNoteIdsMap.get( oldNote.id );
                conversionResult.message = 'Already converted.';

                conversionResultsMap.put( oldNote.id, conversionResult );

                continue;

            }

            // skip if we're not converting private notes
            if ( oldNote.IsPrivate && !this.options.convertPrivateNotes ) {

                ConversionResult conversionResult = new ConversionResult();
                conversionResult.status = ConversionResultStatus.SKIPPED;
                conversionResult.oldNote = oldNote;
                conversionResult.contentNoteId = null;
                conversionResult.message = 'Conversion Settings are set to not convert private notes.';

                conversionResultsMap.put( oldNote.id, conversionResult );

                continue;

            }

            // per Salesforce we must escape certain special characters
            // logic inspired by David Reed (http://www.ktema.org//2016/08/24/importing-notes-into-salesforce/)
            // https://help.salesforce.com/apex/HTViewSolution?id=000230867&language=en_US
            String noteBody = ( String.isBlank( oldNote.body ) ? '<p></p>' : oldNote.body )
                // the escape entity for '&' is '&amp;'
                // so it includes '&' in its own escape sequence, which is a problem
                // because escapeXml() changes '&' to '&amp;' as well
                // so a single '&' would become '&amp;amp;'
                // therefore we first find any normal '&'
                // and replace them with a token value that will
                // be later replaced with '&amp;'
                .replace('&', 'sfdcAMPERSANDsfdc')
                .escapeXml()
                .replace('sfdcAMPERSANDsfdc', '&amp;')
                // handle nitpick on apostrophe html entity
                .replace('&apos;', '&#39;')
                // handle known unsupported non-ascii characters
                // oddly, other symbols like ® ™ are ok unescaped
                .replace('©', '&copy;')
                // handle new lines
                .replace('\r\n', '<br>')
                .replace('\r', '<br>')
                .replace('\n', '<br>')
            ;

            // content version cannot have a null or empty string body
            // so set to empty paragraph which will appear as blank note.
            // we do this after escaping the original note body otherwise
            // the <p> tag would get escaped, doh!
            if ( String.isBlank( noteBody ) ) {
                noteBody = '<p></p>';
            }

            // We set the owner of the new content note to be the
            // same as the note's owner because both fields
            // must have same value to insert the content note.
            // If they do not match then we get error:
            // "Documents in a user's private library must always be owned by that user."
            // The other reason to reference the old record's owner
            // is if the original creator is inactive and the admin
            // needs the new converted file to be owned by an active user.
            // The owner of records can be changed, the created by cannot.

            ContentVersion newNoteVersion = new ContentVersion(
                // data fields
                title = oldNote.title,
                versionData = Blob.valueOf( noteBody ),
                pathOnClient = oldNote.title + '.snote',
                firstPublishLocationId = oldNote.parentId,
                sharingPrivacy = ( oldNote.isPrivate ? 'P' : 'N' ),
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

            // if communities are enabled then assign network id
            if ( communitiesEnabled ) {
                newNoteVersion.put( 'NetworkId', this.networkId );
            }

            newNoteVersions.add( newNoteVersion );

        }

        if ( newNoteVersions.size() > 0 ) {

            SavePoint sp = Database.setSavepoint();

            try {

                Database.DMLOptions dmo = new Database.DMLOptions();
                dmo.optAllOrNone = false;

                List<Database.SaveResult> saveResults = Database.insert( newNoteVersions, dmo );

                for ( Integer i = 0; i < saveResults.size(); i++ ) {

                    Database.SaveResult saveResult = saveResults[i];

                    Note oldNote = oldNotesMap.get( newNoteVersions[i].original_record_id__c );

                    ConversionResult conversionResult = new ConversionResult();
                    conversionResult.status = ( saveResult.isSuccess() ? ConversionResultStatus.CONVERTED : ConversionResultStatus.ERROR );
                    conversionResult.contentNoteId = saveResult.getId();
                    conversionResult.oldNote = oldNote;

                    if ( !saveResult.isSuccess() ) {

                        List<String> messages = new List<String>();

                        for ( Database.Error err : saveResult.getErrors() ) {
                            messages.add( err.getMessage() );
                        }

                        conversionResult.message = String.join( messages, ' ' );

                    }

                    conversionResultsMap.put( oldNote.id, conversionResult );

                }

                postProcessConversionResults( conversionResultsMap );

            } catch ( Exception e ) {

                Database.rollback( sp );
                throw e;

            }

        }

        // sort map values in same order as notes parameter
        List<ConversionResult> conversionResults = new List<ConversionResult>();
        for ( Note oldNote : oldNotes ) {
            conversionResults.add( conversionResultsMap.get( oldNote.id ) );
        }

        return conversionResults;
    }

    private void postProcessConversionResults( Map<ID, ConversionResult> conversionResultsMap ) {

        // should we delete the converted notes?
        if ( this.options.deleteNotesUponConversion ) {
            deleteConvertedNotes( conversionResultsMap );
        }

    }

    // -----------------------------------------------------------------

    private void deleteConvertedNotes( Map<ID, ConversionResult> conversionResultsMap ) {

        List<Note> notesToDelete = new List<Note>();

        for ( ConversionResult conversionResult : conversionResultsMap.values() ) {
            if ( conversionResult.status == ConversionResultStatus.CONVERTED ) {
                notesToDelete.add( conversionResult.oldNote );
            }
        }

        if ( notesToDelete.size() > 0 ) {
            delete notesToDelete;
        }

    }

    /**
     * Given a list of notes then returns the submap of those
     * that have already been converted and their new note ids.
     */
    public Map<ID, ID> getAlreadyConvertedNoteIdsMap( List<Note> notes ) {

        // map of old note ids to new note ids
        Map<ID, ID> convertedNoteIdsMap = new Map<ID, ID>();

        Set<ID> noteIds = new Set<ID>();
        Set<ID> parentIds = new Set<ID>();

        for ( Note note : notes ) {
            noteIds.add( note.id );
            parentIds.add( note.parentId );
        }

        for ( List<ContentDocumentLink> links : [
            SELECT
                contentDocument.latestPublishedVersionId,
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
                        convertedNoteIdsMap.put( link.contentDocument.latestPublishedVersion.original_record_id__c, link.contentDocument.latestPublishedVersionId );
                    }

                }

            }

        }

        return convertedNoteIdsMap;
    }

    public class ConversionResult {

        // was conversion success? skipped? error?
        public ConversionResultStatus status { get; set; }

        // the old note to convert
        public Note oldNote { get; set; }

        // id of the newly converted note if conversion success
        public ID contentNoteId { get; set; }

        // any pertinent message
        public String message { get; set; }

        public ConversionResult() {
            this.message = '';
        }

    }

    public enum ConversionResultStatus {
        CONVERTED, SKIPPED, ERROR
    }

}