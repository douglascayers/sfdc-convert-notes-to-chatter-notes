/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Represents configuration options to pass to conversion service
 * to influence how the conversion will be handled with the notes.
 */
public with sharing class ConvertNotesToContentNotesOptions {

    // The ContentDocumentLink.ShareType value to use for converted notes.
    // This controls user's view/edit ability of the file.
    //
    // Options:
    //     'V' = view only
    //     'I' = inferred view or edit based on user's similar access to related record
    //     'C' = collaborator, view and edit (not supported if related to standard object)
    //
    // The default is 'V'.
    //
    public String shareType { get; set; }

    // The ContentDocumentLink.Visibility value to use for converted notes.
    // This controls whether file is visible to internal users only or all users.
    //
    // Options:
    //     'InternalUsers' = available only to internal users who have permission to see file
    //     'AllUsers' = available to all users, including community users, who have permission to see file
    //
    // If you have communities enabled then consider 'AllUsers' so those users don't lose access to the files.
    // If communities is enabled then default is 'InternalUsers', otherwise 'AllUsers' is only valid value.
    //
    public String visibility { get; set; }

    // Should the Notes be deleted upon conversion to ContentNote?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteNotesUponConversion { get; set; }

    // Classic Notes have a 'IsPrivate' field that when checked the note
    // is only visible to the owner and administrators. To preserve this
    // then the new ContentNote cannot be shared with the parent record
    // because doing so would grant any user who has at least read access
    // to the record to now have read access to the previously private note content.
    // This flag indicates whether privates notes should or should not be converted.
    // If true then a second preference is considered in how private notes will be converted.
    public Boolean convertPrivateNotes { get; set; }

    // Only applicable if 'convertPrivateNotes' is true.
    // Classic Notes have a 'IsPrivate' field that when checked the note
    // is only visible to the owner and administrators. To preserve this
    // then the new ContentNote cannot be shared with the parent record
    // because doing so would grant any user who has at least read access
    // to the record to now have read access to the previously private note content.
    // The alternative is to still convert the note but don't share it with the
    // parent record; however, now the new Notes are not categorized at all
    // so these now technically private new Notes have no context beyond their content.
    // As with the delete option, I err on the side of caution and do nothing unless you enable this option.
    public Boolean sharePrivateNotesWithParentRecord { get; set; }

    // Scope the conversion to just notes related to specific records
    // if null then ALL notes in the system will be converted
    // if empty then NO notes will be converted
    // if non-empty then only notes related to those records will be converted
    public Set<ID> parentIds { get; set; }

    public ConvertNotesToContentNotesOptions() {
        this( Convert_Notes_to_ContentNotes_Settings__c.getInstance() );
    }

    public ConvertNotesToContentNotesOptions( Convert_Notes_to_ContentNotes_Settings__c settings ) {
        this.shareType = settings.share_type__c;
        this.visibility = settings.visibility__c;
        this.deleteNotesUponConversion = settings.delete_note_once_converted__c;
        this.convertPrivateNotes = settings.convert_private_notes__c;
        this.sharePrivateNotesWithParentRecord = settings.share_private_notes__c;
        this.parentIds = null;
    }

}