public inherited sharing class LoanInstallmentDomain extends fflib_SObjectDomain implements ILoanInstallments {
    public interface ILoanInstallments {
        void validateInstallments();
        void validateInstallments(List<Loan_Installment__c> installments);
    }

    private Map<Id, Loan_Installment__c> oldInstallmentsById;

    public static ILoanInstallments newInstance(List<Loan_Installment__c> records) {
        return (ILoanInstallments) ITBA_Application_UTIL.domain.newInstance(records);
    }

    public static ILoanInstallments newInstance(Set<Id> recordIds) {
        return (ILoanInstallments) ITBA_Application_UTIL.domain.newInstance(recordIds);
    }

    public LoanInstallmentDomain(List<Loan_Installment__c> records) {
        super(records);
    }

    public LoanInstallmentDomain(
        List<Loan_Installment__c> records,
        Map<Id, Loan_Installment__c> oldInstallmentsById
    ) {
        super(records);
        this.oldInstallmentsById = oldInstallmentsById;
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new LoanInstallmentDomain((List<Loan_Installment__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        LoanInstallmentService service = new LoanInstallmentService();
        service.prepareInstallments((List<Loan_Installment__c>) getRecords());
        service.validateInstallments((List<Loan_Installment__c>) getRecords());
    }

    public void onBeforeUpdate() {
        this.onBeforeUpdate(getOldRecordsAsSObjects());
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        LoanInstallmentService service = new LoanInstallmentService();
        service.prepareInstallments((List<Loan_Installment__c>) getRecords());
        service.validateInstallments(getChangedInstallments(existingRecords));
    }

    public void validateInstallments() {
        validateInstallments((List<Loan_Installment__c>) getRecords());
    }

    public void validateInstallments(List<Loan_Installment__c> installments) {
        new LoanInstallmentService().validateInstallments(installments);
    }

    private List<Loan_Installment__c> getChangedInstallments(Map<Id, SObject> existingRecords) {
        List<Loan_Installment__c> changedInstallments = new List<Loan_Installment__c>();
        Map<Id, Loan_Installment__c> typedExistingRecords = getOldInstallmentsById(existingRecords);
        if (typedExistingRecords == null || typedExistingRecords.isEmpty()) {
            return changedInstallments;
        }

        for (Loan_Installment__c installment : (List<Loan_Installment__c>) getRecords()) {
            Loan_Installment__c oldInstallment = typedExistingRecords.get(installment.Id);
            if (oldInstallment == null) {
                continue;
            }

            if (installment.Loan__c != oldInstallment.Loan__c ||
                installment.Due_Date__c != oldInstallment.Due_Date__c ||
                installment.Amount__c != oldInstallment.Amount__c ||
                installment.Principal_Component__c != oldInstallment.Principal_Component__c ||
                installment.Interest_Component__c != oldInstallment.Interest_Component__c ||
                installment.Status__c != oldInstallment.Status__c ||
                installment.Paid_Date__c != oldInstallment.Paid_Date__c) {
                changedInstallments.add(installment);
            }
        }

        return changedInstallments;
    }

    private Map<Id, SObject> getOldRecordsAsSObjects() {
        Map<Id, SObject> typedOldRecords = new Map<Id, SObject>();
        if (this.oldInstallmentsById == null) {
            return typedOldRecords;
        }

        for (Id installmentId : this.oldInstallmentsById.keySet()) {
            typedOldRecords.put(installmentId, this.oldInstallmentsById.get(installmentId));
        }

        return typedOldRecords;
    }

    private Map<Id, Loan_Installment__c> getOldInstallmentsById(Map<Id, SObject> existingRecords) {
        if (this.oldInstallmentsById != null) {
            return this.oldInstallmentsById;
        }

        Map<Id, Loan_Installment__c> typedExistingRecords = new Map<Id, Loan_Installment__c>();
        if (existingRecords == null) {
            return typedExistingRecords;
        }

        for (Id installmentId : existingRecords.keySet()) {
            typedExistingRecords.put(installmentId, (Loan_Installment__c) existingRecords.get(installmentId));
        }

        return typedExistingRecords;
    }
}
