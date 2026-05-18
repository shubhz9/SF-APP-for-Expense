public inherited sharing class AssetOwnershipDomain extends fflib_SObjectDomain implements IAssetOwnerships {
    public interface IAssetOwnerships {
        void validateOwnerships();
        void validateOwnerships(List<Asset_Ownership__c> ownerships);
    }

    private Map<Id, Asset_Ownership__c> oldOwnershipsById;

    public static IAssetOwnerships newInstance(List<Asset_Ownership__c> records) {
        return (IAssetOwnerships) ITBA_Application_UTIL.domain.newInstance(records);
    }

    public static IAssetOwnerships newInstance(Set<Id> recordIds) {
        return (IAssetOwnerships) ITBA_Application_UTIL.domain.newInstance(recordIds);
    }

    public AssetOwnershipDomain(List<Asset_Ownership__c> records) {
        super(records);
    }

    public AssetOwnershipDomain(List<Asset_Ownership__c> records, Map<Id, Asset_Ownership__c> oldOwnershipsById) {
        super(records);
        this.oldOwnershipsById = oldOwnershipsById;
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new AssetOwnershipDomain((List<Asset_Ownership__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        validateOwnerships((List<Asset_Ownership__c>) getRecords());
    }

    public void onBeforeUpdate() {
        this.onBeforeUpdate(this.getOldRecordsAsSObjects());
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        validateOwnerships(
            getChangedOwnerships(existingRecords),
            getOldOwnershipsById(existingRecords)
        );
    }

    public void validateOwnerships() {
        validateOwnerships((List<Asset_Ownership__c>) getRecords());
    }

    public void validateOwnerships(List<Asset_Ownership__c> ownerships) {
        validateOwnerships(ownerships, null);
    }

    private void validateOwnerships(
        List<Asset_Ownership__c> ownerships,
        Map<Id, Asset_Ownership__c> oldOwnershipsById
    ) {
        new AssetOwnershipService().validateOwnerships(ownerships, oldOwnershipsById);
    }

    private List<Asset_Ownership__c> getChangedOwnerships(Map<Id, SObject> existingRecords) {
        List<Asset_Ownership__c> changedOwnerships = new List<Asset_Ownership__c>();
        Map<Id, Asset_Ownership__c> typedExistingRecords = getOldOwnershipsById(existingRecords);
        if (typedExistingRecords == null || typedExistingRecords.isEmpty()) {
            return changedOwnerships;
        }

        for (Asset_Ownership__c ownership : (List<Asset_Ownership__c>) getRecords()) {
            Asset_Ownership__c oldOwnership = typedExistingRecords.get(ownership.Id);
            if (oldOwnership == null) {
                continue;
            }

            if (ownership.Shared_Asset__c != oldOwnership.Shared_Asset__c ||
                ownership.Owner__c != oldOwnership.Owner__c ||
                ownership.Ownership_Percentage__c != oldOwnership.Ownership_Percentage__c ||
                ownership.Start_Date__c != oldOwnership.Start_Date__c ||
                ownership.End_Date__c != oldOwnership.End_Date__c ||
                ownership.Is_Active__c != oldOwnership.Is_Active__c ||
                ownership.Total_Contribution__c != oldOwnership.Total_Contribution__c) {
                changedOwnerships.add(ownership);
            }
        }

        return changedOwnerships;
    }

    private Map<Id, SObject> getOldRecordsAsSObjects() {
        Map<Id, SObject> typedOldRecords = new Map<Id, SObject>();
        if (this.oldOwnershipsById == null) {
            return typedOldRecords;
        }

        for (Id ownershipId : this.oldOwnershipsById.keySet()) {
            typedOldRecords.put(ownershipId, this.oldOwnershipsById.get(ownershipId));
        }

        return typedOldRecords;
    }

    private Map<Id, Asset_Ownership__c> getOldOwnershipsById(Map<Id, SObject> existingRecords) {
        if (this.oldOwnershipsById != null) {
            return this.oldOwnershipsById;
        }

        Map<Id, Asset_Ownership__c> typedExistingRecords = new Map<Id, Asset_Ownership__c>();
        if (existingRecords == null) {
            return typedExistingRecords;
        }

        for (Id ownershipId : existingRecords.keySet()) {
            typedExistingRecords.put(ownershipId, (Asset_Ownership__c) existingRecords.get(ownershipId));
        }

        return typedExistingRecords;
    }
}
