/**
 * @description       : 
 * @author            : Shubham Raut
 * @date              : 11-27-2025
 * @last modified on  : 11-27-2025
 * @last modified by  : Shubham Raut
 * Modifications Log
 * Ver   Date         Author         Modification
 * 1.0   11-27-2025   Shubham Raut   Initial Version
**/
trigger TransactionTrigger on Transaction__c (
    before insert,
    before update,
    after insert,
    after update,
    after delete
) {
    List<Transaction__c> triggerRecords = Trigger.isDelete ? Trigger.old : Trigger.new;
    TransactionDomain domain = new TransactionDomain(triggerRecords, Trigger.oldMap);

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            domain.onBeforeInsert();
        }
        if (Trigger.isUpdate) {
            domain.onBeforeUpdate();
        }
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            domain.onAfterInsert();
        }
        if (Trigger.isUpdate) {
            domain.onAfterUpdate();
        }
        if (Trigger.isDelete) {
            domain.onAfterDelete();
        }
    }
}
