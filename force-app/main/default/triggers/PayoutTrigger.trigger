trigger PayoutTrigger on Payout__c (
    before insert,
    before update
) {
    PayoutDomain domain = new PayoutDomain(Trigger.new, Trigger.oldMap);

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            domain.onBeforeInsert();
        }
        if (Trigger.isUpdate) {
            domain.onBeforeUpdate();
        }
    }
}
