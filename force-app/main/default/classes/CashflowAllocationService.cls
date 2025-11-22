public with sharing class CashflowAllocationService {

    public class Request {
        @InvocableVariable(required=true)
        public Id CashflowId;
    }

    @InvocableMethod(
        label='Allocate Cashflow to Participants'
        description='Creates Cashflow_Allocation__c records for the given Cashflow Ids'
    )
    public static void allocate(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> cashflowIds = new Set<Id>();
        for (Request r : requests) {
            if (r != null && r.CashflowId != null) {
                cashflowIds.add(r.CashflowId);
            }
        }
        if (cashflowIds.isEmpty()) {
            return;
        }

        // Load cashflows
        Map<Id, Cashflow__c> cashflows = new Map<Id, Cashflow__c>(
            [
                SELECT Id,
                       Shared_Asset__c,
                       Type__c,
                       Amount__c
                FROM Cashflow__c
                WHERE Id IN :cashflowIds
                  AND Shared_Asset__c != NULL
                  AND Amount__c != NULL
            ]
        );
        if (cashflows.isEmpty()) {
            return;
        }

        // Collect asset ids
        Set<Id> assetIds = new Set<Id>();
        for (Cashflow__c cf : cashflows.values()) {
            assetIds.add(cf.Shared_Asset__c);
        }

        // Load participants per asset
        Map<Id, List<Asset_Participant__c>> participantsByAsset = new Map<Id, List<Asset_Participant__c>>();
        for (Asset_Participant__c ap : [
            SELECT Id,
                   Shared_Asset__c,
                   Ownership_Percentage__c,
                   Loan_Share_Percentage__c,
                   Is_Active__c
            FROM Asset_Participant__c
            WHERE Shared_Asset__c IN :assetIds
              AND Is_Active__c = TRUE
        ]) {
            if (!participantsByAsset.containsKey(ap.Shared_Asset__c)) {
                participantsByAsset.put(ap.Shared_Asset__c, new List<Asset_Participant__c>());
            }
            participantsByAsset.get(ap.Shared_Asset__c).add(ap);
        }

        List<Cashflow_Allocation__c> allocationsToInsert = new List<Cashflow_Allocation__c>();

        for (Cashflow__c cf : cashflows.values()) {
            List<Asset_Participant__c> participants = participantsByAsset.get(cf.Shared_Asset__c);
            if (participants == null || participants.isEmpty()) {
                continue;
            }

            Decimal amount = cf.Amount__c;
            Integer count = participants.size();

            if (count == 0 || amount == null) {
                continue;
            }

            // Simple equal split for now
            Decimal perHead = amount.divide(count, 2, RoundingMode.HALF_UP);

            String allocType = getAllocationType(cf.Type__c);

            for (Asset_Participant__c ap : participants) {
                Cashflow_Allocation__c alloc = new Cashflow_Allocation__c();
                alloc.Cashflow__c = cf.Id;
                alloc.Asset_Participant__c = ap.Id;
                alloc.Allocation_Type__c = allocType;
                alloc.Allocated_Amount__c = perHead;
                allocationsToInsert.add(alloc);
            }
        }

        if (!allocationsToInsert.isEmpty()) {
            insert allocationsToInsert;
        }
    }

    private static String getAllocationType(String cashflowType) {
        if (cashflowType == null) {
            return 'Income_Share';
        }
        switch on cashflowType {
            when 'Contribution' {
                return 'Equity_Contribution';
            }
            when 'Loan_Repayment' {
                return 'Loan_Payment';
            }
            when 'Income' {
                return 'Income_Share';
            }
            when 'Expense' {
                return 'Expense_Share';
            }
            when 'Sale_Proceeds' {
                return 'Profit_Share';
            }
            when else {
                return 'Income_Share';
            }
        }
    }
}