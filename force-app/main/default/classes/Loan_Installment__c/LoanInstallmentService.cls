public with sharing class LoanInstallmentService implements IService {
    public interface IService {
        void prepareInstallments(List<Loan_Installment__c> installments);
        void validateInstallments(List<Loan_Installment__c> installments);
    }

    public void prepareInstallments(List<Loan_Installment__c> installments) {
        if (installments == null || installments.isEmpty()) {
            return;
        }

        for (Loan_Installment__c installment : installments) {
            if (installment.Status__c == null) {
                installment.Status__c = 'Planned';
            }

            Decimal componentTotal = normalize(installment.Principal_Component__c) +
                normalize(installment.Interest_Component__c);
            if (installment.Amount__c == null && componentTotal > 0) {
                installment.Amount__c = componentTotal;
            }

            if (installment.Status__c == 'Paid' && installment.Paid_Date__c == null) {
                installment.Paid_Date__c = Date.today();
            }
        }
    }

    public void validateInstallments(List<Loan_Installment__c> installments) {
        if (installments == null || installments.isEmpty()) {
            return;
        }

        for (Loan_Installment__c installment : installments) {
            if (installment.Due_Date__c == null) {
                installment.Due_Date__c.addError('Due date is required.');
            }

            if (installment.Amount__c == null || installment.Amount__c <= 0) {
                installment.Amount__c.addError('Installment amount must be greater than zero.');
            }

            if (installment.Principal_Component__c != null && installment.Principal_Component__c < 0) {
                installment.Principal_Component__c.addError('Principal component cannot be negative.');
            }

            if (installment.Interest_Component__c != null && installment.Interest_Component__c < 0) {
                installment.Interest_Component__c.addError('Interest component cannot be negative.');
            }

            Decimal componentTotal = normalize(installment.Principal_Component__c) +
                normalize(installment.Interest_Component__c);
            if (installment.Amount__c != null && componentTotal > 0 && componentTotal != installment.Amount__c) {
                installment.Amount__c.addError('Installment amount must equal principal plus interest components.');
            }

            if (installment.Status__c == 'Paid' && installment.Paid_Date__c == null) {
                installment.Paid_Date__c.addError('Paid date is required when installment status is Paid.');
            }

            if (installment.Status__c != 'Paid' && installment.Paid_Date__c != null) {
                installment.Paid_Date__c.addError('Paid date can only be set when installment status is Paid.');
            }
        }
    }

    private static Decimal normalize(Decimal value) {
        return value == null ? 0 : value;
    }
}
