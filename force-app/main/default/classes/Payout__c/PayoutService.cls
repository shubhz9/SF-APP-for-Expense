public with sharing class PayoutService implements IService {
    public interface IService {
        void validatePayouts(List<Payout__c> payouts);
        void validatePayouts(List<Payout__c> payouts, Map<Id, Payout__c> oldPayoutsById);
    }

    public void validatePayouts(List<Payout__c> payouts) {
        validatePayouts(payouts, null);
    }

    public void validatePayouts(List<Payout__c> payouts, Map<Id, Payout__c> oldPayoutsById) {
        if (payouts == null || payouts.isEmpty()) {
            return;
        }

        validateRequiredAndRangeFields(payouts);
        validatePaidPayoutLocks(payouts, oldPayoutsById);
        validatePaymentTransactions(payouts);
    }

    private static void validateRequiredAndRangeFields(List<Payout__c> payouts) {
        for (Payout__c payout : payouts) {
            if (payout.Owner__c == null) {
                payout.Owner__c.addError('Owner is required for payout.');
            }

            if (payout.Amount__c == null || payout.Amount__c <= 0) {
                payout.Amount__c.addError('Payout amount must be greater than zero.');
            }

            if (payout.Ownership_Percentage__c == null ||
                payout.Ownership_Percentage__c <= 0 ||
                payout.Ownership_Percentage__c > 100) {
                payout.Ownership_Percentage__c.addError('Ownership percentage must be greater than 0 and no more than 100.');
            }

            if (payout.Is_Paid__c == true && payout.Payment_Transaction__c == null) {
                payout.Payment_Transaction__c.addError('Payment transaction is required when payout is paid.');
            }

            if (payout.Is_Paid__c != true && payout.Payment_Transaction__c != null) {
                payout.Is_Paid__c.addError('Payout must be marked paid when a payment transaction is selected.');
            }

            if (payout.Transaction__c != null &&
                payout.Payment_Transaction__c != null &&
                payout.Transaction__c == payout.Payment_Transaction__c) {
                payout.Payment_Transaction__c.addError('Payment transaction cannot be the source payout transaction.');
            }
        }
    }

    private static void validatePaidPayoutLocks(List<Payout__c> payouts, Map<Id, Payout__c> oldPayoutsById) {
        if (oldPayoutsById == null || oldPayoutsById.isEmpty()) {
            return;
        }

        for (Payout__c payout : payouts) {
            Payout__c oldPayout = oldPayoutsById.get(payout.Id);
            if (oldPayout == null || oldPayout.Is_Paid__c != true) {
                continue;
            }

            if (payout.Transaction__c != oldPayout.Transaction__c ||
                payout.Owner__c != oldPayout.Owner__c ||
                payout.Ownership_Percentage__c != oldPayout.Ownership_Percentage__c ||
                payout.Amount__c != oldPayout.Amount__c) {
                payout.Amount__c.addError('Paid payout financial details cannot be changed.');
            }
        }
    }

    private static void validatePaymentTransactions(List<Payout__c> payouts) {
        Set<Id> paymentTransactionIds = new Set<Id>();
        for (Payout__c payout : payouts) {
            if (payout.Payment_Transaction__c != null) {
                paymentTransactionIds.add(payout.Payment_Transaction__c);
            }
        }

        if (paymentTransactionIds.isEmpty()) {
            return;
        }

        Map<Id, Transaction__c> paymentTxnById = new Map<Id, Transaction__c>([
            SELECT Id, Type__c, Owner__c, Amount__c
            FROM Transaction__c
            WHERE Id IN :paymentTransactionIds
        ]);

        for (Payout__c payout : payouts) {
            if (payout.Payment_Transaction__c == null) {
                continue;
            }

            Transaction__c paymentTxn = paymentTxnById.get(payout.Payment_Transaction__c);
            if (paymentTxn == null) {
                continue;
            }

            if (paymentTxn.Type__c != 'Profit_Distribution') {
                payout.Payment_Transaction__c.addError('Payment transaction must be a profit distribution transaction.');
            }

            if (payout.Owner__c != null && paymentTxn.Owner__c != payout.Owner__c) {
                payout.Payment_Transaction__c.addError('Payment transaction owner must match payout owner.');
            }

            if (payout.Amount__c != null && paymentTxn.Amount__c != null && paymentTxn.Amount__c < payout.Amount__c) {
                payout.Payment_Transaction__c.addError('Payment transaction amount cannot be less than payout amount.');
            }
        }
    }
}
