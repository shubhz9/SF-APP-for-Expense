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
public with sharing class TransactionService {

    // Types that should map to INWARD / OUTWARD directions
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

    // ----------------------------
    // Direction derivation helpers
    // ----------------------------

    public static void setDirections(List<Transaction__c> txns) {
        if (txns == null || txns.isEmpty()) return;

        for (Transaction__c t : txns) {
            if (t.Type__c == null) {
                continue;
            }

            if (INWARD_TYPES.contains(t.Type__c)) {
                t.Direction__c = 'Inward';
            } else if (OUTWARD_TYPES.contains(t.Type__c)) {
                t.Direction__c = 'Outward';
            }
            // If Type__c not in either set, leave Direction__c as-is
        }
    }

    // ------------------------------------
    // Payout generation (Income / Returns)
    // ------------------------------------

    public static void generatePayoutsForNew(List<Transaction__c> newTxns) {
        generatePayoutsInternal(newTxns, null);
    }

    public static void generatePayoutsForUpdated(
        List<Transaction__c> newTxns,
        Map<Id, Transaction__c> oldTxnsById
    ) {
        generatePayoutsInternal(newTxns, oldTxnsById);
    }

    /**
     * Core payout generator:
     * - Only for Type__c IN ('Income_From_Asset', 'Return')
     * - Requires Shared_Asset__c and Amount__c
     * - On update, only acts when something relevant changed
     */
    private static void generatePayoutsInternal(
        List<Transaction__c> newTxns,
        Map<Id, Transaction__c> oldTxnsById
    ) {
        if (newTxns == null || newTxns.isEmpty()) return;

        List<Transaction__c> eligible = new List<Transaction__c>();

        for (Transaction__c t : newTxns) {
            if (t.Type__c == null || t.Amount__c == null || t.Shared_Asset__c == null) {
                continue;
            }

            Boolean isIncomeType =
                t.Type__c == 'Income_From_Asset' ||
                t.Type__c == 'Return';

            if (!isIncomeType) {
                continue;
            }

            // For updates, only re-generate payouts if something changed
            if (oldTxnsById != null && oldTxnsById.containsKey(t.Id)) {
                Transaction__c oldT = oldTxnsById.get(t.Id);

                Boolean typeUnchanged = (oldT.Type__c == t.Type__c);
                Boolean amountUnchanged = (oldT.Amount__c == t.Amount__c);
                Boolean assetUnchanged = (oldT.Shared_Asset__c == t.Shared_Asset__c);

                if (typeUnchanged && amountUnchanged && assetUnchanged) {
                    // nothing relevant changed, skip
                    continue;
                }
            }

            eligible.add(t);
        }

        if (eligible.isEmpty()) {
            return;
        }

        // Collect asset ids
        Set<Id> assetIds = new Set<Id>();
        for (Transaction__c t : eligible) {
            assetIds.add(t.Shared_Asset__c);
        }

        // Query active ownership records
        Map<Id, List<Asset_Ownership__c>> ownershipByAssetId =
            new Map<Id, List<Asset_Ownership__c>>();

        for (Asset_Ownership__c own : [
            SELECT Id,
                   Shared_Asset__c,
                   Owner__c,
                   Ownership_Percentage__c,
                   Is_Active__c
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c IN :assetIds
              AND Is_Active__c = true
              AND Ownership_Percentage__c != null
        ]) {
            List<Asset_Ownership__c> bucket = ownershipByAssetId.get(own.Shared_Asset__c);
            if (bucket == null) {
                bucket = new List<Asset_Ownership__c>();
                ownershipByAssetId.put(own.Shared_Asset__c, bucket);
            }
            bucket.add(own);
        }

        if (ownershipByAssetId.isEmpty()) {
            return;
        }

        // Optional: clean up existing payouts for these transactions before re-creating
        // (so updates don't double-create)
        Set<Id> txnIds = new Set<Id>();
        for (Transaction__c t : eligible) {
            if (t.Id != null) {
                txnIds.add(t.Id);
            }
        }

        List<Payout__c> payoutsToDelete = new List<Payout__c>();
        if (!txnIds.isEmpty()) {
            payoutsToDelete = [
                SELECT Id
                FROM Payout__c
                WHERE Transaction__c IN :txnIds
            ];
        }

        List<Payout__c> payoutsToInsert = new List<Payout__c>();

        for (Transaction__c t : eligible) {
            List<Asset_Ownership__c> owners = ownershipByAssetId.get(t.Shared_Asset__c);
            if (owners == null || owners.isEmpty()) {
                continue;
            }

            for (Asset_Ownership__c own : owners) {
                Decimal percent = own.Ownership_Percentage__c;
                if (percent == null) continue;

                Decimal shareAmount = (t.Amount__c * percent) / 100;

                Payout__c p = new Payout__c();
                p.Transaction__c         = t.Id;
                p.Owner__c               = own.Owner__c;
                p.Ownership_Percentage__c = percent;
                p.Amount__c              = shareAmount;
                p.Is_Paid__c             = false;
                // Payment_Transaction__c and Remarks__c can be filled later manually / via another process

                payoutsToInsert.add(p);
            }
        }

        // Perform DML in bulk
        if (!payoutsToDelete.isEmpty()) {
            delete payoutsToDelete;
        }
        if (!payoutsToInsert.isEmpty()) {
            insert payoutsToInsert;
        }
    }
}
