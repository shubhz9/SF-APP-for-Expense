/**
 * @description       :
 * @author            : Shubham Raut
 * @date              : 12-01-2025
 * @last modified on  : 12-01-2025
 * @last modified by  : Shubham Raut
 * Modifications Log
 * Ver   Date         Author         Modification
 * 1.0   11-27-2025   Shubham Raut   Initial Version
 **/
public with sharing class TransactionService implements IService {
    public interface IService {
        void applyDirection(List<Transaction__c> newTxns);
        void processIncomeAndReturnTransactions(List<Transaction__c> newTxns);
        void processIncomeAndReturnTransactions(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void refreshRelatedRollups(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void refreshRelatedRollups(List<Transaction__c> newTxns, List<Transaction__c> oldTxns);
    }

    private static final Set<String> INWARD_TYPES = new Set<String>{
        'Down_Payment',
        'Owner_Contribution',
        'Loan_Disbursement',
        'Income_From_Asset',
        'Return',
        'Other_Income'
    };

    private static final Set<String> OUTWARD_TYPES = new Set<String>{
        'Loan_Repayment',
        'Interest_Payment',
        'Maintenance_Expense',
        'Insurance',
        'Profit_Distribution',
        'Other_Expense'
    };

    private static final Set<String> OWNER_REQUIRED_TYPES = new Set<String>{
        'Down_Payment',
        'Owner_Contribution',
        'Profit_Distribution'
    };

    private static final Set<String> LOAN_REQUIRED_TYPES = new Set<String>{
        'Loan_Disbursement',
        'Loan_Repayment',
        'Interest_Payment'
    };

    private static final Set<String> CONTRIBUTION_TYPES = new Set<String>{
        'Down_Payment',
        'Owner_Contribution'
    };

    public void applyDirection(List<Transaction__c> txns) {
        if (txns == null || txns.isEmpty()) {
            return;
        }

        for (Transaction__c txn : txns) {
            if (String.isBlank(txn.Type__c)) {
                continue;
            }

            if (INWARD_TYPES.contains(txn.Type__c)) {
                txn.Direction__c = 'Inward';
            } else if (OUTWARD_TYPES.contains(txn.Type__c)) {
                txn.Direction__c = 'Outward';
            }
        }
    }

    public static Boolean requiresOwner(String transactionType) {
        return OWNER_REQUIRED_TYPES.contains(transactionType);
    }

    public static Boolean requiresLoan(String transactionType) {
        return LOAN_REQUIRED_TYPES.contains(transactionType);
    }

    public void processIncomeAndReturnTransactions(List<Transaction__c> newTxns) {
        processIncomeAndReturnTransactions(newTxns, null);
    }

    public void processIncomeAndReturnTransactions(
        List<Transaction__c> newTxns,
        Map<Id, Transaction__c> oldTxnsById
    ) {
        if (newTxns == null || newTxns.isEmpty()) {
            return;
        }

        List<Transaction__c> eligible = new List<Transaction__c>();
        Set<Id> txnIdsToDeletePayouts = new Set<Id>();

        for (Transaction__c txn : newTxns) {
            Boolean shouldProcess = true;
            if (oldTxnsById != null && txn.Id != null && oldTxnsById.containsKey(txn.Id)) {
                Transaction__c oldTxn = oldTxnsById.get(txn.Id);
                shouldProcess =
                    txn.Type__c != oldTxn.Type__c ||
                    txn.Amount__c != oldTxn.Amount__c ||
                    txn.Shared_Asset__c != oldTxn.Shared_Asset__c;
            }

            if (!shouldProcess) {
                continue;
            }

            if (oldTxnsById != null && txn.Id != null) {
                txnIdsToDeletePayouts.add(txn.Id);
            }

            if (isPayoutGeneratingTransaction(txn)) {
                eligible.add(txn);
            }
        }

        if (eligible.isEmpty() && txnIdsToDeletePayouts.isEmpty()) {
            return;
        }

        Set<Id> assetIds = new Set<Id>();
        for (Transaction__c txn : eligible) {
            assetIds.add(txn.Shared_Asset__c);
        }

        Map<Id, List<Asset_Ownership__c>> ownershipByAssetId = new Map<Id, List<Asset_Ownership__c>>();
        for (Asset_Ownership__c ownership : AssetOwnershipSelector.newInstance().selectBySharedAssets(assetIds)) {
            List<Asset_Ownership__c> bucket = ownershipByAssetId.get(ownership.Shared_Asset__c);
            if (bucket == null) {
                bucket = new List<Asset_Ownership__c>();
                ownershipByAssetId.put(ownership.Shared_Asset__c, bucket);
            }
            bucket.add(ownership);
        }

        List<Payout__c> payoutsToDelete = new List<Payout__c>();
        if (oldTxnsById != null && !txnIdsToDeletePayouts.isEmpty()) {
            payoutsToDelete = PayoutSelector.newInstance().selectByTransactionIds(txnIdsToDeletePayouts);
        }

        List<Payout__c> payoutsToInsert = new List<Payout__c>();
        for (Transaction__c txn : eligible) {
            List<Asset_Ownership__c> owners = ownershipByAssetId.get(txn.Shared_Asset__c);
            if (owners == null || owners.isEmpty()) {
                continue;
            }

            for (Asset_Ownership__c ownership : owners) {
                Decimal pct = ownership.Ownership_Percentage__c;
                if (pct == null) {
                    continue;
                }

                payoutsToInsert.add(new Payout__c(
                    Transaction__c = txn.Id,
                    Owner__c = ownership.Owner__c,
                    Ownership_Percentage__c = pct,
                    Amount__c = (txn.Amount__c * pct) / 100,
                    Is_Paid__c = false
                ));
            }
        }

        if (!payoutsToDelete.isEmpty()) {
            delete payoutsToDelete;
        }
        if (!payoutsToInsert.isEmpty()) {
            insert payoutsToInsert;
        }
    }

    public void refreshRelatedRollups(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById) {
        refreshRelatedRollups(newTxns, oldTxnsById == null ? null : oldTxnsById.values());
    }

    public void refreshRelatedRollups(List<Transaction__c> newTxns, List<Transaction__c> oldTxns) {
        Set<Id> loanIds = new Set<Id>();
        Set<Id> installmentIds = new Set<Id>();
        Set<Id> assetIds = new Set<Id>();

        collectAffectedRollupIds(newTxns, loanIds, installmentIds, assetIds);
        collectAffectedRollupIds(oldTxns, loanIds, installmentIds, assetIds);

        refreshLoanInstallments(installmentIds);
        refreshLoans(loanIds);
        refreshOwnerContributions(assetIds);
    }

    private static void collectAffectedRollupIds(
        List<Transaction__c> txns,
        Set<Id> loanIds,
        Set<Id> installmentIds,
        Set<Id> assetIds
    ) {
        if (txns == null || txns.isEmpty()) {
            return;
        }

        for (Transaction__c txn : txns) {
            if (txn == null) {
                continue;
            }
            if (txn.Loan__c != null) {
                loanIds.add(txn.Loan__c);
            }
            if (txn.Loan_Installment__c != null) {
                installmentIds.add(txn.Loan_Installment__c);
            }
            if (txn.Shared_Asset__c != null) {
                assetIds.add(txn.Shared_Asset__c);
            }
        }
    }

    private void refreshLoanInstallments(Set<Id> installmentIds) {
        if (installmentIds == null || installmentIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> paidAmountByInstallmentId = new Map<Id, Decimal>();
        Map<Id, Date> latestPaidDateByInstallmentId = new Map<Id, Date>();

        for (AggregateResult result : [
            SELECT Loan_Installment__c installmentId,
                SUM(Amount__c) paidAmount,
                MAX(Transaction_Date__c) latestPayment
            FROM Transaction__c
            WHERE Loan_Installment__c IN :installmentIds
                AND Type__c IN ('Loan_Repayment', 'Interest_Payment')
            GROUP BY Loan_Installment__c
        ]) {
            Id installmentId = (Id) result.get('installmentId');
            paidAmountByInstallmentId.put(installmentId, (Decimal) result.get('paidAmount'));

            Object latestPayment = result.get('latestPayment');
            if (latestPayment != null) {
                latestPaidDateByInstallmentId.put(installmentId, ((DateTime) latestPayment).date());
            }
        }

        List<Loan_Installment__c> installmentsToUpdate = new List<Loan_Installment__c>();
        for (Loan_Installment__c installment : LoanInstallmentSelector.newInstance().selectByIds(installmentIds)) {
            Decimal paidAmount = paidAmountByInstallmentId.get(installment.Id);
            if (paidAmount == null) {
                paidAmount = 0;
            }

            String nextStatus;
            Date nextPaidDate;
            if (installment.Amount__c != null && paidAmount >= installment.Amount__c) {
                nextStatus = 'Paid';
                nextPaidDate = latestPaidDateByInstallmentId.get(installment.Id);
            } else if (installment.Due_Date__c != null && installment.Due_Date__c < Date.today()) {
                nextStatus = 'Overdue';
            } else {
                nextStatus = 'Pending';
            }

            if (installment.Status__c != nextStatus || installment.Paid_Date__c != nextPaidDate) {
                installmentsToUpdate.add(new Loan_Installment__c(
                    Id = installment.Id,
                    Status__c = nextStatus,
                    Paid_Date__c = nextPaidDate
                ));
            }
        }

        if (!installmentsToUpdate.isEmpty()) {
            update installmentsToUpdate;
        }
    }

    private void refreshLoans(Set<Id> loanIds) {
        if (loanIds == null || loanIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> disbursedByLoanId = new Map<Id, Decimal>();
        Map<Id, Decimal> repaidByLoanId = new Map<Id, Decimal>();

        for (AggregateResult result : [
            SELECT Loan__c loanId,
                Type__c transactionType,
                SUM(Amount__c) totalAmount
            FROM Transaction__c
            WHERE Loan__c IN :loanIds
                AND Type__c IN ('Loan_Disbursement', 'Loan_Repayment')
            GROUP BY Loan__c, Type__c
        ]) {
            Id loanId = (Id) result.get('loanId');
            String transactionType = (String) result.get('transactionType');
            Decimal totalAmount = (Decimal) result.get('totalAmount');

            if (transactionType == 'Loan_Disbursement') {
                disbursedByLoanId.put(loanId, totalAmount);
            } else if (transactionType == 'Loan_Repayment') {
                repaidByLoanId.put(loanId, totalAmount);
            }
        }

        List<Loan__c> loansToUpdate = new List<Loan__c>();
        for (Loan__c loan : LoanSelector.newInstance().selectByIds(loanIds)) {
            Decimal principal = loan.Principal_Amount__c;
            if (principal == null) {
                principal = disbursedByLoanId.get(loan.Id);
            }
            if (principal == null) {
                principal = 0;
            }

            Decimal repaid = repaidByLoanId.get(loan.Id);
            if (repaid == null) {
                repaid = 0;
            }

            Decimal outstanding = principal - repaid;
            if (outstanding < 0) {
                outstanding = 0;
            }

            String nextStatus = loan.Status__c;
            if (principal > 0 && outstanding == 0) {
                nextStatus = 'Closed';
            } else if (loan.Status__c == null || loan.Status__c == 'Closed') {
                nextStatus = 'Active';
            }

            if (loan.Outstanding_Principal__c != outstanding || loan.Status__c != nextStatus) {
                loansToUpdate.add(new Loan__c(
                    Id = loan.Id,
                    Outstanding_Principal__c = outstanding,
                    Status__c = nextStatus
                ));
            }
        }

        if (!loansToUpdate.isEmpty()) {
            update loansToUpdate;
        }
    }

    private void refreshOwnerContributions(Set<Id> assetIds) {
        if (assetIds == null || assetIds.isEmpty()) {
            return;
        }

        Map<String, Decimal> contributionByAssetOwnerKey = new Map<String, Decimal>();
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                Owner__c ownerId,
                SUM(Amount__c) totalContribution
            FROM Transaction__c
            WHERE Shared_Asset__c IN :assetIds
                AND Owner__c != null
                AND Type__c IN :CONTRIBUTION_TYPES
            GROUP BY Shared_Asset__c, Owner__c
        ]) {
            contributionByAssetOwnerKey.put(
                buildAssetOwnerKey((Id) result.get('assetId'), (Id) result.get('ownerId')),
                (Decimal) result.get('totalContribution')
            );
        }

        List<Asset_Ownership__c> ownershipsToUpdate = new List<Asset_Ownership__c>();
        for (Asset_Ownership__c ownership : AssetOwnershipSelector.newInstance().selectBySharedAssets(assetIds)) {
            Decimal contribution = contributionByAssetOwnerKey.get(
                buildAssetOwnerKey(ownership.Shared_Asset__c, ownership.Owner__c)
            );
            if (contribution == null) {
                contribution = 0;
            }

            if (ownership.Total_Contribution__c != contribution) {
                ownershipsToUpdate.add(new Asset_Ownership__c(
                    Id = ownership.Id,
                    Total_Contribution__c = contribution
                ));
            }
        }

        if (!ownershipsToUpdate.isEmpty()) {
            update ownershipsToUpdate;
        }
    }

    private static String buildAssetOwnerKey(Id assetId, Id ownerId) {
        return String.valueOf(assetId) + ':' + String.valueOf(ownerId);
    }

    private static Boolean isPayoutGeneratingTransaction(Transaction__c txn) {
        return txn.Type__c != null &&
            txn.Amount__c != null &&
            txn.Shared_Asset__c != null &&
            (txn.Type__c == 'Income_From_Asset' || txn.Type__c == 'Return');
    }
}
