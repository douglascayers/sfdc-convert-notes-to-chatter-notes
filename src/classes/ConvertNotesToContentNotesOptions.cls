/**
 * Developed by Doug Ayers (douglascayers.com)
 *
 * Represents configuration options to pass to conversion service
 * to influence how the conversion will be handled with the notes.
 */
public with sharing class ConvertNotesToContentNotesOptions {

    // Should the Notes be deleted upon conversion to ContentNote?
    // Deleting them reduces redundant data storage.
    // Make sure you've backed up your data before enabling this.
    public Boolean deleteNotesUponConversion { get; set; }

    // Scope the conversion to just notes related to specific records
    // if null then ALL notes in the system will be converted
    // if empty then NO notes will be converted
    // if non-empty then only notes related to those records will be converted
    public Set<ID> parentIds { get; set; }

    public ConvertNotesToContentNotesOptions() {
        this( Convert_Notes_to_ContentNotes_Settings__c.getInstance() );
    }

    public ConvertNotesToContentNotesOptions( Convert_Notes_to_ContentNotes_Settings__c settings ) {
        this.deleteNotesUponConversion = settings.delete_note_once_converted__c;
        this.parentIds = null;
    }

}