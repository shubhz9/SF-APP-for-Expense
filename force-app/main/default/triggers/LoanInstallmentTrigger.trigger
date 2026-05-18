trigger LoanInstallmentTrigger on Loan_Installment__c (
    before insert,
    before update
) {
    LoanInstallmentDomain domain = new LoanInstallmentDomain(Trigger.new, Trigger.oldMap);

    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            domain.onBeforeInsert();
        }
        if (Trigger.isUpdate) {
            domain.onBeforeUpdate();
        }
    }
}
