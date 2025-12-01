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
public with sharing class TransactionService implements IService{

    public interface IService{
        void applyDirection(List<Transaction__c> newTxns);
        void processIncomeAndReturnTransactions(List<Transaction__c> newTxns, Map<Id, Transaction__c> oldTxnsById);
        void processIncomeAndReturnTransactions(List<Transaction__c> newTxns);
    }

    // --------------------------------
    // 1. Direction based on Type__c
    // --------------------------------

    // Types treated as "money coming into" the asset
    private static final Set<String> INWARD_TYPES = new Set<String>{
        'Down_Payment',
        'Owner_Contribution',
        'Loan_Disbursement',
        'Income_From_Asset',
        'Return',
        'Other_Income'
    };

    // Types treated as "money going out" of the asset
    private static final Set<String> OUTWARD_TYPES = new Set<String>{
        'Loan_Repayment',
        'Interest_Payment',
        'Maintenance_Expense',
        'Insurance',
        'Profit_Distribution',
        'Other_Expense'
    };

    /**
     * Automation #2:
     * Auto-set Direction__c based on Type__c.
     * To be called in BEFORE INSERT / BEFORE UPDATE.
     */
    public void applyDirection(List<Transaction__c> txns) {
        if (txns == null || txns.isEmpty()) return;

        for (Transaction__c t : txns) {
            if (t.Type__c == null) {
                // no type → don't touch direction
                continue;
            }

            if (INWARD_TYPES.contains(t.Type__c)) {
                t.Direction__c = 'Inward';
            } else if (OUTWARD_TYPES.contains(t.Type__c)) {
                t.Direction__c = 'Outward';
            }
            // If Type__c not in either list, leave Direction__c as-is
        }
    }

    // -------------------------------------------
    // 2. Payouts for Income_From_Asset / Return
    // -------------------------------------------

    /**
     * Public entry method for AFTER INSERT.
     * Automation #1:
     *  - For new Return / Income_From_Asset transactions,
     *  - Auto-create Payout__c records per active ownership.
     */
    public void processIncomeAndReturnTransactions(List<Transaction__c> newTxns) {
        processIncomeAndReturnTransactions(newTxns, null);
    }

    /**
     * Public entry method for AFTER UPDATE.
     * Automation #1:
     *  - Same logic as insert,
     *  - But only re-generates payouts if relevant fields changed.
     */
    public void processIncomeAndReturnTransactions(
        List<Transaction__c> newTxns,
        Map<Id, Transaction__c> oldTxnsById
    ) {
        if (newTxns == null || newTxns.isEmpty()) return;

        // Step 1: filter transactions that qualify
        List<Transaction__c> eligible = new List<Transaction__c>();

        for (Transaction__c t : newTxns) {
            if (t.Type__c == null ||
                t.Amount__c == null ||
                t.Shared_Asset__c == null) {
                continue;
            }

            Boolean isIncomeType =
                t.Type__c == 'Income_From_Asset' ||
                t.Type__c == 'Return';

            if (!isIncomeType) {
                continue;
            }

            eligible.add(t);
        }

        if (eligible.isEmpty()) {
            return;
        }

        // Step 2: get all related assets
        Set<Id> assetIds = new Set<Id>();
        for (Transaction__c t : eligible) {
            assetIds.add(t.Shared_Asset__c);
        }

        // Step 3: query active ownership per asset
        Map<Id, List<Asset_Ownership__c>> ownershipByAssetId =
            new Map<Id, List<Asset_Ownership__c>>();

        for (Asset_Ownership__c own : AssetOwnershipSelector.newInstance().selectBySharedAssets(assetIds)) {
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

        // Step 4: if update, wipe existing payouts for these txns to avoid duplicates
        Set<Id> txnIds = new Set<Id>();
        for (Transaction__c t : eligible) {
            if (t.Id != null) {
                txnIds.add(t.Id);
            }
        }

        List<Payout__c> payoutsToDelete = new List<Payout__c>();
        if (!txnIds.isEmpty()) {
            payoutsToDelete = PayoutSelector.newInstance().selectByTransactionIds(txnIds);
        }

        // Step 5: create new Payout__c records based on ownership %
        List<Payout__c> payoutsToInsert = new List<Payout__c>();

        for (Transaction__c t : eligible) {
            List<Asset_Ownership__c> owners = ownershipByAssetId.get(t.Shared_Asset__c);
            if (owners == null || owners.isEmpty()) {
                continue;
            }

            for (Asset_Ownership__c own : owners) {
                Decimal pct = own.Ownership_Percentage__c;
                if (pct == null) continue;

                Decimal shareAmount = (t.Amount__c * pct) / 100;

                Payout__c p = new Payout__c();
                p.Transaction__c          = t.Id;
                p.Owner__c                = own.Owner__c;
                p.Ownership_Percentage__c = pct;
                p.Amount__c               = shareAmount;
                p.Is_Paid__c              = false;
                // Payment_Transaction__c, Remarks__c can be filled later

                payoutsToInsert.add(p);
            }
        }

        // Step 6: DML in bulk
        if (!payoutsToDelete.isEmpty()) {
            delete payoutsToDelete;
        }
        if (!payoutsToInsert.isEmpty()) {
            insert payoutsToInsert;
        }
    }
}
