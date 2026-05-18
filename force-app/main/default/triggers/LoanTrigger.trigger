trigger LoanTrigger on Loan__c (
    before insert,
    before update
) {
    LoanDomain domain = new LoanDomain(Trigger.new, Trigger.oldMap);

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            domain.onBeforeInsert();
        }
        if (Trigger.isUpdate) {
            domain.onBeforeUpdate();
        }
    }
}
