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
        void prepareRelatedRecords(List<Transaction__c> newTxns);
        void validateTransactionContexts(List<Transaction__c> newTxns);
        void validateTransactionContexts(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void processIncomeAndReturnTransactions(List<Transaction__c> newTxns);
        void processIncomeAndReturnTransactions(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void processProfitDistributionTransactions(List<Transaction__c> newTxns);
        void processProfitDistributionTransactions(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void refreshRelatedRollups(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void refreshRelatedRollups(List<Transaction__c> newTxns, List<Transaction__c> oldTxns);
    }

    public void applyDirection(List<Transaction__c> txns) {
        if (txns == null || txns.isEmpty()) {
            return;
        }

        for (Transaction__c txn : txns) {
            if (String.isBlank(txn.Type__c)) {
                continue;
            }

            TransactionTypeConfig.TransactionTypeRule rule = TransactionTypeConfig.ruleFor(txn.Type__c);
            if (rule != null) {
                txn.Direction__c = rule.direction;
            }
        }
    }

    public static Boolean requiresOwner(String transactionType) {
        return TransactionTypeConfig.requiresOwner(transactionType);
    }

    public static Boolean requiresLoan(String transactionType) {
        return TransactionTypeConfig.requiresLoan(transactionType);
    }

    public void validateTransactionContexts(List<Transaction__c> txns) {
        validateTransactionContexts(txns, null);
    }

    public void validateTransactionContexts(List<Transaction__c> txns, Map<Id, Transaction__c> oldTxnsById) {
        if (txns == null || txns.isEmpty()) {
            return;
        }

        validateAssetsAreReady(txns);
        validateLoanTransactions(txns, oldTxnsById);
        validateProfitDistributionAmounts(txns);
    }

    public void prepareRelatedRecords(List<Transaction__c> txns) {
        if (txns == null || txns.isEmpty()) {
            return;
        }

        createAndLinkLoans(txns);
        createAndLinkLoanInstallments(txns);
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

    public void processProfitDistributionTransactions(List<Transaction__c> newTxns) {
        processProfitDistributionTransactions(newTxns, null);
    }

    public void processProfitDistributionTransactions(
        List<Transaction__c> newTxns,
        Map<Id, Transaction__c> oldTxnsById
    ) {
        if (newTxns == null || newTxns.isEmpty()) {
            return;
        }

        Set<Id> paymentTxnIdsToClear = new Set<Id>();
        List<Transaction__c> eligible = new List<Transaction__c>();
        Set<Id> assetIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();

        for (Transaction__c txn : newTxns) {
            if (txn.Id == null) {
                continue;
            }

            Boolean shouldProcess = true;
            if (oldTxnsById != null && oldTxnsById.containsKey(txn.Id)) {
                Transaction__c oldTxn = oldTxnsById.get(txn.Id);
                shouldProcess =
                    txn.Type__c != oldTxn.Type__c ||
                    txn.Amount__c != oldTxn.Amount__c ||
                    txn.Shared_Asset__c != oldTxn.Shared_Asset__c ||
                    txn.Owner__c != oldTxn.Owner__c;
            }

            if (!shouldProcess) {
                continue;
            }

            if (oldTxnsById != null) {
                paymentTxnIdsToClear.add(txn.Id);
            }

            if (isProfitDistributionTransaction(txn)) {
                eligible.add(txn);
                assetIds.add(txn.Shared_Asset__c);
                ownerIds.add(txn.Owner__c);
            }
        }

        if (eligible.isEmpty() && paymentTxnIdsToClear.isEmpty()) {
            return;
        }

        List<Payout__c> payoutsToUpdate = new List<Payout__c>();
        if (!paymentTxnIdsToClear.isEmpty()) {
            for (Payout__c payout : [
                SELECT Id, Is_Paid__c, Payment_Transaction__c
                FROM Payout__c
                WHERE Payment_Transaction__c IN :paymentTxnIdsToClear
            ]) {
                payout.Is_Paid__c = false;
                payout.Payment_Transaction__c = null;
                payoutsToUpdate.add(payout);
            }
        }

        if (!eligible.isEmpty()) {
            List<Payout__c> candidatePayouts = [
                SELECT Id, Owner__c, Amount__c, Is_Paid__c, Payment_Transaction__c,
                    Transaction__r.Shared_Asset__c
                FROM Payout__c
                WHERE Is_Paid__c = false
                    AND Payment_Transaction__c = null
                    AND Owner__c IN :ownerIds
                    AND Transaction__r.Shared_Asset__c IN :assetIds
                ORDER BY Transaction__r.Transaction_Date__c ASC, CreatedDate ASC
            ];

            Set<Id> selectedPayoutIds = new Set<Id>();
            for (Transaction__c txn : eligible) {
                Decimal remainingAmount = txn.Amount__c;
                for (Payout__c payout : candidatePayouts) {
                    if (selectedPayoutIds.contains(payout.Id) ||
                        payout.Owner__c != txn.Owner__c ||
                        payout.Transaction__r.Shared_Asset__c != txn.Shared_Asset__c ||
                        payout.Amount__c == null ||
                        payout.Amount__c > remainingAmount) {
                        continue;
                    }

                    payout.Is_Paid__c = true;
                    payout.Payment_Transaction__c = txn.Id;
                    payoutsToUpdate.add(payout);
                    selectedPayoutIds.add(payout.Id);
                    remainingAmount -= payout.Amount__c;

                    if (remainingAmount == 0) {
                        break;
                    }
                }
            }
        }

        if (!payoutsToUpdate.isEmpty()) {
            update payoutsToUpdate;
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
        Set<String> contributionTypes = TransactionTypeConfig.ownerContributionTypes();
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                Owner__c ownerId,
                SUM(Amount__c) totalContribution
            FROM Transaction__c
            WHERE Shared_Asset__c IN :assetIds
                AND Owner__c != null
                AND Type__c IN :contributionTypes
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

    private void createAndLinkLoans(List<Transaction__c> txns) {
        List<Transaction__c> loanDisbursements = new List<Transaction__c>();
        for (Transaction__c txn : txns) {
            if (txn.Type__c == 'Loan_Disbursement' &&
                txn.Loan__c == null &&
                txn.Shared_Asset__c != null &&
                txn.Amount__c != null &&
                txn.Amount__c > 0) {
                loanDisbursements.add(txn);
            }
        }

        if (loanDisbursements.isEmpty()) {
            return;
        }

        List<Loan__c> loansToInsert = new List<Loan__c>();
        for (Transaction__c txn : loanDisbursements) {
            loansToInsert.add(new Loan__c(
                Shared_Asset__c = txn.Shared_Asset__c,
                Principal_Amount__c = txn.Amount__c,
                Outstanding_Principal__c = txn.Amount__c,
                Start_Date__c = txn.Transaction_Date__c == null ? Date.today() : txn.Transaction_Date__c.date(),
                Status__c = 'Active'
            ));
        }

        insert loansToInsert;

        for (Integer index = 0; index < loanDisbursements.size(); index++) {
            loanDisbursements[index].Loan__c = loansToInsert[index].Id;
        }
    }

    private void createAndLinkLoanInstallments(List<Transaction__c> txns) {
        List<Transaction__c> paymentTxns = new List<Transaction__c>();
        for (Transaction__c txn : txns) {
            if ((txn.Type__c == 'Loan_Repayment' || txn.Type__c == 'Interest_Payment') &&
                txn.Loan__c != null &&
                txn.Loan_Installment__c == null &&
                txn.Amount__c != null &&
                txn.Amount__c > 0) {
                paymentTxns.add(txn);
            }
        }

        if (paymentTxns.isEmpty()) {
            return;
        }

        List<Loan_Installment__c> installmentsToInsert = new List<Loan_Installment__c>();
        for (Transaction__c txn : paymentTxns) {
            Date txnDate = txn.Transaction_Date__c == null ? Date.today() : txn.Transaction_Date__c.date();
            installmentsToInsert.add(new Loan_Installment__c(
                Loan__c = txn.Loan__c,
                Due_Date__c = txnDate,
                Amount__c = txn.Amount__c,
                Principal_Component__c = txn.Type__c == 'Loan_Repayment' ? txn.Amount__c : 0,
                Interest_Component__c = txn.Type__c == 'Interest_Payment' ? txn.Amount__c : 0,
                Status__c = 'Planned'
            ));
        }

        insert installmentsToInsert;

        for (Integer index = 0; index < paymentTxns.size(); index++) {
            paymentTxns[index].Loan_Installment__c = installmentsToInsert[index].Id;
        }
    }

    private static Boolean isPayoutGeneratingTransaction(Transaction__c txn) {
        return txn.Type__c != null &&
            txn.Amount__c != null &&
            txn.Shared_Asset__c != null &&
            TransactionTypeConfig.generatesPayout(txn.Type__c);
    }

    private static Boolean isProfitDistributionTransaction(Transaction__c txn) {
        return TransactionTypeConfig.isProfitDistribution(txn.Type__c) &&
            txn.Amount__c != null &&
            txn.Amount__c > 0 &&
            txn.Shared_Asset__c != null &&
            txn.Owner__c != null;
    }

    private static void validateAssetsAreReady(List<Transaction__c> txns) {
        Set<Id> assetIds = new Set<Id>();
        for (Transaction__c txn : txns) {
            if (txn.Shared_Asset__c != null && TransactionTypeConfig.requiresAsset(txn.Type__c)) {
                assetIds.add(txn.Shared_Asset__c);
            }
        }

        if (assetIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> activePercentageByAssetId = new Map<Id, Decimal>();
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                SUM(Ownership_Percentage__c) totalPercentage
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c IN :assetIds
                AND Is_Active__c = true
                AND Ownership_Percentage__c != null
            GROUP BY Shared_Asset__c
        ]) {
            activePercentageByAssetId.put((Id) result.get('assetId'), (Decimal) result.get('totalPercentage'));
        }

        for (Transaction__c txn : txns) {
            if (txn.Shared_Asset__c == null || !TransactionTypeConfig.requiresAsset(txn.Type__c)) {
                continue;
            }

            Decimal activePercentage = activePercentageByAssetId.get(txn.Shared_Asset__c);
            if (activePercentage == null || activePercentage != 100) {
                txn.Shared_Asset__c.addError('Active ownership percentages must total 100% before transactions can be recorded.');
            }
        }
    }

    private static void validateLoanTransactions(List<Transaction__c> txns, Map<Id, Transaction__c> oldTxnsById) {
        Set<Id> loanIds = new Set<Id>();
        Map<Id, Decimal> principalRepaymentDeltaByLoanId = new Map<Id, Decimal>();

        for (Transaction__c txn : txns) {
            if (txn.Loan__c == null || String.isBlank(txn.Type__c)) {
                continue;
            }

            if (txn.Type__c == 'Loan_Disbursement' ||
                txn.Type__c == 'Loan_Repayment' ||
                txn.Type__c == 'Interest_Payment') {
                loanIds.add(txn.Loan__c);
            }

            if (!TransactionTypeConfig.isLoanPrincipalRepayment(txn.Type__c) || txn.Amount__c == null) {
                continue;
            }

            Decimal delta = txn.Amount__c;
            if (oldTxnsById != null && txn.Id != null && oldTxnsById.containsKey(txn.Id)) {
                Transaction__c oldTxn = oldTxnsById.get(txn.Id);
                if (oldTxn.Loan__c == txn.Loan__c && TransactionTypeConfig.isLoanPrincipalRepayment(oldTxn.Type__c)) {
                    delta -= oldTxn.Amount__c == null ? 0 : oldTxn.Amount__c;
                }
            }
            incrementAmount(principalRepaymentDeltaByLoanId, txn.Loan__c, delta);
        }

        if (loanIds.isEmpty()) {
            return;
        }

        Map<Id, Loan__c> loansById = new Map<Id, Loan__c>([
            SELECT Id, Status__c, Outstanding_Principal__c
            FROM Loan__c
            WHERE Id IN :loanIds
        ]);

        for (Transaction__c txn : txns) {
            if (txn.Loan__c == null) {
                continue;
            }

            Loan__c loan = loansById.get(txn.Loan__c);
            if (loan == null) {
                continue;
            }

            if ((txn.Type__c == 'Loan_Disbursement' || txn.Type__c == 'Loan_Repayment' || txn.Type__c == 'Interest_Payment') &&
                loan.Status__c == 'Closed') {
                txn.Loan__c.addError('Closed loans cannot receive new loan transactions.');
            }
        }

        for (Transaction__c txn : txns) {
            if (!TransactionTypeConfig.isLoanPrincipalRepayment(txn.Type__c) || txn.Loan__c == null) {
                continue;
            }

            Loan__c loan = loansById.get(txn.Loan__c);
            Decimal delta = principalRepaymentDeltaByLoanId.get(txn.Loan__c);
            Decimal outstanding = loan == null || loan.Outstanding_Principal__c == null ? 0 : loan.Outstanding_Principal__c;
            if (delta != null && delta > outstanding) {
                txn.Amount__c.addError('Loan repayment cannot exceed outstanding principal.');
            }
        }
    }

    private static void validateProfitDistributionAmounts(List<Transaction__c> txns) {
        List<Transaction__c> distributions = new List<Transaction__c>();
        Set<Id> assetIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();

        for (Transaction__c txn : txns) {
            if (isProfitDistributionTransaction(txn)) {
                distributions.add(txn);
                assetIds.add(txn.Shared_Asset__c);
                ownerIds.add(txn.Owner__c);
            }
        }

        if (distributions.isEmpty()) {
            return;
        }

        Map<String, List<Decimal>> openPayoutAmountsByAssetOwnerKey = new Map<String, List<Decimal>>();
        for (Payout__c payout : [
            SELECT Owner__c, Amount__c, Transaction__r.Shared_Asset__c
            FROM Payout__c
            WHERE Is_Paid__c = false
                AND Payment_Transaction__c = null
                AND Owner__c IN :ownerIds
                AND Transaction__r.Shared_Asset__c IN :assetIds
            ORDER BY Transaction__r.Transaction_Date__c ASC, CreatedDate ASC
        ]) {
            String key = buildAssetOwnerKey(payout.Transaction__r.Shared_Asset__c, payout.Owner__c);
            if (!openPayoutAmountsByAssetOwnerKey.containsKey(key)) {
                openPayoutAmountsByAssetOwnerKey.put(key, new List<Decimal>());
            }
            openPayoutAmountsByAssetOwnerKey.get(key).add(payout.Amount__c);
        }

        for (Transaction__c txn : distributions) {
            String key = buildAssetOwnerKey(txn.Shared_Asset__c, txn.Owner__c);
            List<Decimal> openAmounts = openPayoutAmountsByAssetOwnerKey.get(key);
            if (!canFullyAllocate(txn.Amount__c, openAmounts)) {
                txn.Amount__c.addError('Profit distribution must exactly match one or more unpaid payouts for this owner and asset.');
            }
        }
    }

    private static Boolean canFullyAllocate(Decimal amount, List<Decimal> openAmounts) {
        if (amount == null || amount <= 0 || openAmounts == null || openAmounts.isEmpty()) {
            return false;
        }

        Decimal remainingAmount = amount;
        for (Decimal openAmount : openAmounts) {
            if (openAmount == null || openAmount > remainingAmount) {
                continue;
            }
            remainingAmount -= openAmount;
            if (remainingAmount == 0) {
                return true;
            }
        }
        return remainingAmount == 0;
    }

    private static void incrementAmount(Map<Id, Decimal> totalsById, Id recordId, Decimal amount) {
        Decimal currentTotal = totalsById.get(recordId);
        if (currentTotal == null) {
            currentTotal = 0;
        }
        totalsById.put(recordId, currentTotal + amount);
    }
}
