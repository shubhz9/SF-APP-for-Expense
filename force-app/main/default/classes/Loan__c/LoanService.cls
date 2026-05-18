public with sharing class LoanService implements IService {
    public interface IService {
        void prepareLoans(List<Loan__c> loans);
        void validateLoans(List<Loan__c> loans);
    }

    public void prepareLoans(List<Loan__c> loans) {
        if (loans == null || loans.isEmpty()) {
            return;
        }

        for (Loan__c loan : loans) {
            if (loan.Status__c == null) {
                loan.Status__c = 'Active';
            }

            if (loan.Outstanding_Principal__c == null && loan.Principal_Amount__c != null) {
                loan.Outstanding_Principal__c = loan.Principal_Amount__c;
            }
        }
    }

    public void validateLoans(List<Loan__c> loans) {
        if (loans == null || loans.isEmpty()) {
            return;
        }

        for (Loan__c loan : loans) {
            if (loan.Principal_Amount__c == null || loan.Principal_Amount__c <= 0) {
                loan.Principal_Amount__c.addError('Principal amount must be greater than zero.');
            }

            if (loan.Outstanding_Principal__c != null) {
                if (loan.Outstanding_Principal__c < 0) {
                    loan.Outstanding_Principal__c.addError('Outstanding principal cannot be negative.');
                } else if (loan.Principal_Amount__c != null && loan.Outstanding_Principal__c > loan.Principal_Amount__c) {
                    loan.Outstanding_Principal__c.addError('Outstanding principal cannot exceed principal amount.');
                }
            }

            if (loan.Interest_Rate__c != null && (loan.Interest_Rate__c < 0 || loan.Interest_Rate__c > 100)) {
                loan.Interest_Rate__c.addError('Interest rate must be between 0 and 100.');
            }

            if (loan.EMI_Amount__c != null && loan.EMI_Amount__c <= 0) {
                loan.EMI_Amount__c.addError('EMI amount must be greater than zero.');
            }

            if (loan.Start_Date__c != null && loan.End_Date__c != null && loan.End_Date__c < loan.Start_Date__c) {
                loan.End_Date__c.addError('End date cannot be before start date.');
            }

            if (loan.Status__c == 'Closed' && loan.Outstanding_Principal__c != null && loan.Outstanding_Principal__c > 0) {
                loan.Status__c.addError('Loan cannot be closed while outstanding principal remains.');
            }
        }
    }
}
