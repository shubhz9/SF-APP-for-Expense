public with sharing class FinancialPositionService {
    public class OwnerPosition {
        public Id assetId;
        public Id ownerId;
        public Decimal ownershipPercentage = 0;
        public Decimal totalContributions = 0;
        public Decimal totalExpensesPaid = 0;
        public Decimal expectedExpenseResponsibility = 0;
        public Decimal payoutGenerated = 0;
        public Decimal payoutReceived = 0;
        public Decimal profitDistributions = 0;
        public Decimal netReceivable = 0;
        public Decimal netPayable = 0;
    }

    public class AssetPosition {
        public Id assetId;
        public Decimal purchasePrice = 0;
        public Decimal currentValue = 0;
        public Decimal totalInwardCash = 0;
        public Decimal totalOutwardCash = 0;
        public Decimal netCashPosition = 0;
        public Decimal totalOwnerContributions = 0;
        public Decimal totalLoanFunding = 0;
        public Decimal totalLoanPrincipalRepaid = 0;
        public Decimal totalInterest = 0;
        public Decimal maintenanceExpenses = 0;
        public Decimal insuranceExpenses = 0;
        public Decimal otherExpenses = 0;
        public Decimal income = 0;
        public Decimal returns = 0;
        public Decimal payouts = 0;
        public Decimal profitDistributions = 0;
        public Decimal outstandingLoan = 0;
        public Decimal assetGainLoss = 0;
    }

    private static final Set<String> CONTRIBUTION_TYPES = new Set<String>{ 'Down_Payment', 'Owner_Contribution' };
    private static final Set<String> EXPENSE_TYPES = new Set<String>{ 'Maintenance_Expense', 'Insurance', 'Other_Expense' };

    public static Map<String, OwnerPosition> calculateOwnerPositions(Set<Id> assetIds) {
        Map<String, OwnerPosition> positionsByKey = new Map<String, OwnerPosition>();
        if (assetIds == null || assetIds.isEmpty()) {
            return positionsByKey;
        }

        seedOwnerPositions(assetIds, positionsByKey);
        applyOwnerTransactions(assetIds, positionsByKey);
        applyExpenseAllocations(assetIds, positionsByKey);
        applyPayouts(assetIds, positionsByKey);
        finishOwnerPositions(positionsByKey);
        return positionsByKey;
    }

    public static Map<Id, AssetPosition> calculateAssetPositions(Set<Id> assetIds) {
        Map<Id, AssetPosition> positionsByAssetId = new Map<Id, AssetPosition>();
        if (assetIds == null || assetIds.isEmpty()) {
            return positionsByAssetId;
        }

        for (Shared_Asset__c asset : [
            SELECT Id, Purchase_Price__c, Current_Value__c
            FROM Shared_Asset__c
            WHERE Id IN :assetIds
        ]) {
            AssetPosition position = new AssetPosition();
            position.assetId = asset.Id;
            position.purchasePrice = normalize(asset.Purchase_Price__c);
            position.currentValue = normalize(asset.Current_Value__c);
            position.assetGainLoss = position.currentValue - position.purchasePrice;
            positionsByAssetId.put(asset.Id, position);
        }

        applyAssetTransactions(assetIds, positionsByAssetId);
        applyAssetLoans(assetIds, positionsByAssetId);
        return positionsByAssetId;
    }

    private static void seedOwnerPositions(Set<Id> assetIds, Map<String, OwnerPosition> positionsByKey) {
        for (Asset_Ownership__c ownership : [
            SELECT Shared_Asset__c, Owner__c, Ownership_Percentage__c
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c IN :assetIds
                AND Is_Active__c = true
                AND Owner__c != null
        ]) {
            OwnerPosition position = getOwnerPosition(
                positionsByKey,
                ownership.Shared_Asset__c,
                ownership.Owner__c
            );
            position.ownershipPercentage = normalize(ownership.Ownership_Percentage__c);
        }
    }

    private static void applyOwnerTransactions(Set<Id> assetIds, Map<String, OwnerPosition> positionsByKey) {
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                Owner__c ownerId,
                Type__c txnType,
                SUM(Amount__c) totalAmount
            FROM Transaction__c
            WHERE Shared_Asset__c IN :assetIds
                AND Owner__c != null
                AND Type__c IN ('Down_Payment', 'Owner_Contribution', 'Maintenance_Expense', 'Insurance', 'Other_Expense', 'Profit_Distribution')
            GROUP BY Shared_Asset__c, Owner__c, Type__c
        ]) {
            Id assetId = (Id) result.get('assetId');
            Id ownerId = (Id) result.get('ownerId');
            String txnType = (String) result.get('txnType');
            Decimal totalAmount = normalize((Decimal) result.get('totalAmount'));
            OwnerPosition position = getOwnerPosition(positionsByKey, assetId, ownerId);

            if (CONTRIBUTION_TYPES.contains(txnType)) {
                position.totalContributions += totalAmount;
            } else if (EXPENSE_TYPES.contains(txnType)) {
                position.totalExpensesPaid += totalAmount;
            } else if (txnType == 'Profit_Distribution') {
                position.profitDistributions += totalAmount;
            }
        }
    }

    private static void applyExpenseAllocations(Set<Id> assetIds, Map<String, OwnerPosition> positionsByKey) {
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                Owner__c ownerId,
                SUM(Expected_Amount__c) expectedAmount
            FROM Expense_Allocation__c
            WHERE Shared_Asset__c IN :assetIds
                AND Owner__c != null
            GROUP BY Shared_Asset__c, Owner__c
        ]) {
            OwnerPosition position = getOwnerPosition(
                positionsByKey,
                (Id) result.get('assetId'),
                (Id) result.get('ownerId')
            );
            position.expectedExpenseResponsibility += normalize((Decimal) result.get('expectedAmount'));
        }
    }

    private static void applyPayouts(Set<Id> assetIds, Map<String, OwnerPosition> positionsByKey) {
        for (AggregateResult result : [
            SELECT Transaction__r.Shared_Asset__c assetId,
                Owner__c ownerId,
                Is_Paid__c paid,
                SUM(Amount__c) totalAmount
            FROM Payout__c
            WHERE Transaction__r.Shared_Asset__c IN :assetIds
                AND Owner__c != null
            GROUP BY Transaction__r.Shared_Asset__c, Owner__c, Is_Paid__c
        ]) {
            OwnerPosition position = getOwnerPosition(
                positionsByKey,
                (Id) result.get('assetId'),
                (Id) result.get('ownerId')
            );
            Decimal totalAmount = normalize((Decimal) result.get('totalAmount'));
            position.payoutGenerated += totalAmount;
            if ((Boolean) result.get('paid') == true) {
                position.payoutReceived += totalAmount;
            }
        }
    }

    private static void finishOwnerPositions(Map<String, OwnerPosition> positionsByKey) {
        for (OwnerPosition position : positionsByKey.values()) {
            Decimal expenseNet = position.totalExpensesPaid - position.expectedExpenseResponsibility;
            Decimal payoutNet = position.payoutGenerated - position.profitDistributions;
            Decimal net = expenseNet + payoutNet;
            position.netReceivable = net > 0 ? net : 0;
            position.netPayable = net < 0 ? net.abs() : 0;
        }
    }

    private static void applyAssetTransactions(Set<Id> assetIds, Map<Id, AssetPosition> positionsByAssetId) {
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                Direction__c direction,
                Type__c txnType,
                SUM(Amount__c) totalAmount
            FROM Transaction__c
            WHERE Shared_Asset__c IN :assetIds
            GROUP BY Shared_Asset__c, Direction__c, Type__c
        ]) {
            Id assetId = (Id) result.get('assetId');
            AssetPosition position = positionsByAssetId.get(assetId);
            if (position == null) {
                position = new AssetPosition();
                position.assetId = assetId;
                positionsByAssetId.put(assetId, position);
            }

            Decimal totalAmount = normalize((Decimal) result.get('totalAmount'));
            String direction = (String) result.get('direction');
            String txnType = (String) result.get('txnType');

            if (direction == 'Inward') {
                position.totalInwardCash += totalAmount;
            } else if (direction == 'Outward') {
                position.totalOutwardCash += totalAmount;
            }

            if (CONTRIBUTION_TYPES.contains(txnType)) {
                position.totalOwnerContributions += totalAmount;
            } else if (txnType == 'Loan_Disbursement') {
                position.totalLoanFunding += totalAmount;
            } else if (txnType == 'Loan_Repayment') {
                position.totalLoanPrincipalRepaid += totalAmount;
            } else if (txnType == 'Interest_Payment') {
                position.totalInterest += totalAmount;
            } else if (txnType == 'Maintenance_Expense') {
                position.maintenanceExpenses += totalAmount;
            } else if (txnType == 'Insurance') {
                position.insuranceExpenses += totalAmount;
            } else if (txnType == 'Other_Expense') {
                position.otherExpenses += totalAmount;
            } else if (txnType == 'Income_From_Asset') {
                position.income += totalAmount;
            } else if (txnType == 'Return') {
                position.returns += totalAmount;
            } else if (txnType == 'Profit_Distribution') {
                position.profitDistributions += totalAmount;
                position.payouts += totalAmount;
            }
        }

        for (AssetPosition position : positionsByAssetId.values()) {
            position.netCashPosition = position.totalInwardCash - position.totalOutwardCash;
        }
    }

    private static void applyAssetLoans(Set<Id> assetIds, Map<Id, AssetPosition> positionsByAssetId) {
        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                SUM(Outstanding_Principal__c) outstandingPrincipal
            FROM Loan__c
            WHERE Shared_Asset__c IN :assetIds
            GROUP BY Shared_Asset__c
        ]) {
            AssetPosition position = positionsByAssetId.get((Id) result.get('assetId'));
            if (position != null) {
                position.outstandingLoan = normalize((Decimal) result.get('outstandingPrincipal'));
            }
        }
    }

    private static OwnerPosition getOwnerPosition(Map<String, OwnerPosition> positionsByKey, Id assetId, Id ownerId) {
        String key = buildKey(assetId, ownerId);
        if (!positionsByKey.containsKey(key)) {
            OwnerPosition position = new OwnerPosition();
            position.assetId = assetId;
            position.ownerId = ownerId;
            positionsByKey.put(key, position);
        }
        return positionsByKey.get(key);
    }

    public static String buildKey(Id assetId, Id ownerId) {
        return String.valueOf(assetId) + ':' + String.valueOf(ownerId);
    }

    private static Decimal normalize(Decimal value) {
        return value == null ? 0 : value;
    }
}
