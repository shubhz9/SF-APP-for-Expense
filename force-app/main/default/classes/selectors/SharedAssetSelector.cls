/* SharedAssetSelector.cls */
public inherited sharing class SharedAssetSelector extends fflib_SObjectSelector {

    /* 1. sObjectField list */
    private List<String> additionalSObjectFieldList = new List<String>{
        'Id',
        'Name',
        'Category__c',
        'Purchase_Date__c',
        'Purchase_Price__c',
        'Current_Value__c',
        'Status__c'
    };

    /* 2. Boilerplate code */
    public static SharedAssetSelector newInstance() {
        return (SharedAssetSelector) ITBA_Application_UTIL.selector.newInstance(
            Shared_Asset__c.SObjectType
        );
    }

    public Schema.SObjectType getSObjectType() {
        return Shared_Asset__c.SObjectType;
    }

    public fflib_QueryFactory getQueryFactory() {
        return new fflib_QueryFactory(getSObjectType());
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Shared_Asset__c.Id,
            Shared_Asset__c.Name,
            Shared_Asset__c.Category__c,
            Shared_Asset__c.Purchase_Date__c,
            Shared_Asset__c.Purchase_Price__c,
            Shared_Asset__c.Current_Value__c,
            Shared_Asset__c.Status__c
        };
    }

    public override Set<String> getRelatedFieldSet(){
        return new Set<String>{};
    }

    @TestVisible
    private List<Schema.SObjectField> getAdditionalSObjectFieldList() {
        return new List<Schema.SObjectField>{};
    }

    /* 3. Selector Methods */
    public List<Shared_Asset__c> selectByIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Id IN :idSet');
        return (List<Shared_Asset__c>) Database.query(queryFactory.toSOQL());
    }
}
