public with sharing class AssetOwnershipService implements IService {
    public interface IService {
        void validateOwnerships(List<Asset_Ownership__c> ownerships);
        void validateOwnerships(List<Asset_Ownership__c> ownerships, Map<Id, Asset_Ownership__c> oldOwnershipsById);
    }

    public void validateOwnerships(List<Asset_Ownership__c> ownerships) {
        validateOwnerships(ownerships, null);
    }

    public void validateOwnerships(
        List<Asset_Ownership__c> ownerships,
        Map<Id, Asset_Ownership__c> oldOwnershipsById
    ) {
        if (ownerships == null || ownerships.isEmpty()) {
            return;
        }

        validateRequiredAndRangeFields(ownerships);
        validateDuplicateActiveOwners(ownerships);
        validateActiveOwnershipTotals(ownerships);
    }

    private static void validateRequiredAndRangeFields(List<Asset_Ownership__c> ownerships) {
        for (Asset_Ownership__c ownership : ownerships) {
            if (ownership.Owner__c == null) {
                ownership.Owner__c.addError('Owner is required for asset ownership.');
            }

            if (ownership.Is_Active__c == true) {
                if (ownership.Ownership_Percentage__c == null) {
                    ownership.Ownership_Percentage__c.addError('Active ownership requires an ownership percentage.');
                } else if (ownership.Ownership_Percentage__c <= 0 || ownership.Ownership_Percentage__c > 100) {
                    ownership.Ownership_Percentage__c.addError('Ownership percentage must be greater than 0 and no more than 100.');
                }
            } else if (ownership.Ownership_Percentage__c != null &&
                (ownership.Ownership_Percentage__c < 0 || ownership.Ownership_Percentage__c > 100)) {
                ownership.Ownership_Percentage__c.addError('Ownership percentage must be between 0 and 100.');
            }

            if (ownership.Start_Date__c != null &&
                ownership.End_Date__c != null &&
                ownership.End_Date__c < ownership.Start_Date__c) {
                ownership.End_Date__c.addError('End date cannot be before start date.');
            }

            if (ownership.Total_Contribution__c != null && ownership.Total_Contribution__c < 0) {
                ownership.Total_Contribution__c.addError('Total contribution cannot be negative.');
            }
        }
    }

    private static void validateDuplicateActiveOwners(List<Asset_Ownership__c> ownerships) {
        Map<String, List<Asset_Ownership__c>> activeRowsByAssetOwnerKey = new Map<String, List<Asset_Ownership__c>>();
        Set<Id> assetIds = new Set<Id>();
        Set<Id> currentOwnershipIds = new Set<Id>();

        for (Asset_Ownership__c ownership : ownerships) {
            if (ownership.Id != null) {
                currentOwnershipIds.add(ownership.Id);
            }
            if (!isActiveWithRequiredLookup(ownership)) {
                continue;
            }

            assetIds.add(ownership.Shared_Asset__c);
            String key = buildAssetOwnerKey(ownership.Shared_Asset__c, ownership.Owner__c);
            if (!activeRowsByAssetOwnerKey.containsKey(key)) {
                activeRowsByAssetOwnerKey.put(key, new List<Asset_Ownership__c>());
            }
            activeRowsByAssetOwnerKey.get(key).add(ownership);
        }

        for (String key : activeRowsByAssetOwnerKey.keySet()) {
            if (activeRowsByAssetOwnerKey.get(key).size() > 1) {
                for (Asset_Ownership__c ownership : activeRowsByAssetOwnerKey.get(key)) {
                    ownership.Owner__c.addError('An owner can only have one active ownership record for the same asset.');
                }
            }
        }

        if (assetIds.isEmpty()) {
            return;
        }

        for (Asset_Ownership__c existing : [
            SELECT Id, Shared_Asset__c, Owner__c
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c IN :assetIds
                AND Is_Active__c = true
                AND Owner__c != null
        ]) {
            if (currentOwnershipIds.contains(existing.Id)) {
                continue;
            }

            String key = buildAssetOwnerKey(existing.Shared_Asset__c, existing.Owner__c);
            if (!activeRowsByAssetOwnerKey.containsKey(key)) {
                continue;
            }

            for (Asset_Ownership__c ownership : activeRowsByAssetOwnerKey.get(key)) {
                ownership.Owner__c.addError('An owner can only have one active ownership record for the same asset.');
            }
        }
    }

    private static void validateActiveOwnershipTotals(List<Asset_Ownership__c> ownerships) {
        Map<Id, Decimal> activePercentageByAssetId = new Map<Id, Decimal>();
        Map<Id, List<Asset_Ownership__c>> activeRowsByAssetId = new Map<Id, List<Asset_Ownership__c>>();
        Set<Id> assetIds = new Set<Id>();
        Set<Id> currentOwnershipIds = new Set<Id>();

        for (Asset_Ownership__c ownership : ownerships) {
            if (ownership.Id != null) {
                currentOwnershipIds.add(ownership.Id);
            }
            if (ownership.Shared_Asset__c == null ||
                ownership.Is_Active__c != true ||
                ownership.Ownership_Percentage__c == null) {
                continue;
            }

            assetIds.add(ownership.Shared_Asset__c);
            incrementPercentage(activePercentageByAssetId, ownership.Shared_Asset__c, ownership.Ownership_Percentage__c);
            if (!activeRowsByAssetId.containsKey(ownership.Shared_Asset__c)) {
                activeRowsByAssetId.put(ownership.Shared_Asset__c, new List<Asset_Ownership__c>());
            }
            activeRowsByAssetId.get(ownership.Shared_Asset__c).add(ownership);
        }

        if (assetIds.isEmpty()) {
            return;
        }

        for (AggregateResult result : [
            SELECT Shared_Asset__c assetId,
                SUM(Ownership_Percentage__c) totalPercentage
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c IN :assetIds
                AND Is_Active__c = true
                AND Ownership_Percentage__c != null
                AND Id NOT IN :currentOwnershipIds
            GROUP BY Shared_Asset__c
        ]) {
            incrementPercentage(
                activePercentageByAssetId,
                (Id) result.get('assetId'),
                (Decimal) result.get('totalPercentage')
            );
        }

        for (Id assetId : activePercentageByAssetId.keySet()) {
            if (activePercentageByAssetId.get(assetId) <= 100) {
                continue;
            }

            for (Asset_Ownership__c ownership : activeRowsByAssetId.get(assetId)) {
                ownership.Ownership_Percentage__c.addError('Active ownership percentages for an asset cannot exceed 100%.');
            }
        }
    }

    private static Boolean isActiveWithRequiredLookup(Asset_Ownership__c ownership) {
        return ownership.Shared_Asset__c != null &&
            ownership.Owner__c != null &&
            ownership.Is_Active__c == true;
    }

    private static void incrementPercentage(Map<Id, Decimal> totalsByAssetId, Id assetId, Decimal percentage) {
        Decimal currentTotal = totalsByAssetId.get(assetId);
        if (currentTotal == null) {
            currentTotal = 0;
        }
        totalsByAssetId.put(assetId, currentTotal + percentage);
    }

    private static String buildAssetOwnerKey(Id assetId, Id ownerId) {
        return String.valueOf(assetId) + ':' + String.valueOf(ownerId);
    }
}
