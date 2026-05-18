/* AssetOwnershipSelector.cls */
public inherited sharing class AssetOwnershipSelector extends fflib_SObjectSelector {

    /* 1. sObjectField list */
    private List<String> additionalSObjectFieldList = new List<String>{
        'Id',
        'Name',
        'Shared_Asset__c',
        'Owner__c',
        'Ownership_Percentage__c',
        'Total_Contribution__c',
        'Start_Date__c',
        'End_Date__c',
        'Is_Active__c'
    };

    /* 2. Boilerplate code */
    public static AssetOwnershipSelector newInstance() {
        return (AssetOwnershipSelector) ITBA_Application_UTIL.selector.newInstance(
            Asset_Ownership__c.SObjectType
        );
    }

    public Schema.SObjectType getSObjectType() {
        return Asset_Ownership__c.SObjectType;
    }

    public fflib_QueryFactory getQueryFactory() {
        return new fflib_QueryFactory(getSObjectType());
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Asset_Ownership__c.Id,
            Asset_Ownership__c.Name,
            Asset_Ownership__c.Shared_Asset__c,
            Asset_Ownership__c.Owner__c,
            Asset_Ownership__c.Ownership_Percentage__c,
            Asset_Ownership__c.Total_Contribution__c,
            Asset_Ownership__c.Start_Date__c,
            Asset_Ownership__c.End_Date__c,
            Asset_Ownership__c.Is_Active__c
        };
    }

    public override Set<String> getRelatedFieldSet(){
        return new Set<String>{
            'Shared_Asset__c.Name',
            'Owner__c.Name'
        };
    }

    @TestVisible
    private List<Schema.SObjectField> getAdditionalSObjectFieldList() {
        return new List<Schema.SObjectField>{};
    }

    /* 3. Selector Methods */
    public List<Asset_Ownership__c> selectByIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Id IN :idSet');
        return (List<Asset_Ownership__c>) Database.query(queryFactory.toSOQL());
    }

    public List<Asset_Ownership__c> selectBySharedAssets(Set<Id> assetIds) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Shared_Asset__c IN :assetIds AND Is_Active__c = true AND Ownership_Percentage__c != null');
        return (List<Asset_Ownership__c>) Database.query(queryFactory.toSOQL());
    }
}
