public inherited sharing class LoanDomain extends fflib_SObjectDomain implements ILoans {
    public interface ILoans {
        void validateLoans();
        void validateLoans(List<Loan__c> loans);
    }

    private Map<Id, Loan__c> oldLoansById;

    public static ILoans newInstance(List<Loan__c> records) {
        return (ILoans) ITBA_Application_UTIL.domain.newInstance(records);
    }

    public static ILoans newInstance(Set<Id> recordIds) {
        return (ILoans) ITBA_Application_UTIL.domain.newInstance(recordIds);
    }

    public LoanDomain(List<Loan__c> records) {
        super(records);
    }

    public LoanDomain(List<Loan__c> records, Map<Id, Loan__c> oldLoansById) {
        super(records);
        this.oldLoansById = oldLoansById;
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new LoanDomain((List<Loan__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        LoanService service = new LoanService();
        service.prepareLoans((List<Loan__c>) getRecords());
        service.validateLoans((List<Loan__c>) getRecords());
    }

    public void onBeforeUpdate() {
        this.onBeforeUpdate(getOldRecordsAsSObjects());
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        LoanService service = new LoanService();
        service.prepareLoans((List<Loan__c>) getRecords());
        service.validateLoans(getChangedLoans(existingRecords));
    }

    public void validateLoans() {
        validateLoans((List<Loan__c>) getRecords());
    }

    public void validateLoans(List<Loan__c> loans) {
        new LoanService().validateLoans(loans);
    }

    private List<Loan__c> getChangedLoans(Map<Id, SObject> existingRecords) {
        List<Loan__c> changedLoans = new List<Loan__c>();
        Map<Id, Loan__c> typedExistingRecords = getOldLoansById(existingRecords);
        if (typedExistingRecords == null || typedExistingRecords.isEmpty()) {
            return changedLoans;
        }

        for (Loan__c loan : (List<Loan__c>) getRecords()) {
            Loan__c oldLoan = typedExistingRecords.get(loan.Id);
            if (oldLoan == null) {
                continue;
            }

            if (loan.Shared_Asset__c != oldLoan.Shared_Asset__c ||
                loan.Principal_Amount__c != oldLoan.Principal_Amount__c ||
                loan.Outstanding_Principal__c != oldLoan.Outstanding_Principal__c ||
                loan.Interest_Rate__c != oldLoan.Interest_Rate__c ||
                loan.Start_Date__c != oldLoan.Start_Date__c ||
                loan.End_Date__c != oldLoan.End_Date__c ||
                loan.Status__c != oldLoan.Status__c ||
                loan.EMI_Amount__c != oldLoan.EMI_Amount__c) {
                changedLoans.add(loan);
            }
        }

        return changedLoans;
    }

    private Map<Id, SObject> getOldRecordsAsSObjects() {
        Map<Id, SObject> typedOldRecords = new Map<Id, SObject>();
        if (this.oldLoansById == null) {
            return typedOldRecords;
        }

        for (Id loanId : this.oldLoansById.keySet()) {
            typedOldRecords.put(loanId, this.oldLoansById.get(loanId));
        }

        return typedOldRecords;
    }

    private Map<Id, Loan__c> getOldLoansById(Map<Id, SObject> existingRecords) {
        if (this.oldLoansById != null) {
            return this.oldLoansById;
        }

        Map<Id, Loan__c> typedExistingRecords = new Map<Id, Loan__c>();
        if (existingRecords == null) {
            return typedExistingRecords;
        }

        for (Id loanId : existingRecords.keySet()) {
            typedExistingRecords.put(loanId, (Loan__c) existingRecords.get(loanId));
        }

        return typedExistingRecords;
    }
}
