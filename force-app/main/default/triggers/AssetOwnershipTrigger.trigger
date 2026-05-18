trigger AssetOwnershipTrigger on Asset_Ownership__c (
    before insert,
    before update
) {
    List<Asset_Ownership__c> triggerRecords = Trigger.new;
    AssetOwnershipDomain domain = new AssetOwnershipDomain(triggerRecords, Trigger.oldMap);

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            domain.onBeforeInsert();
        }
        if (Trigger.isUpdate) {
            domain.onBeforeUpdate();
        }
    }
}
