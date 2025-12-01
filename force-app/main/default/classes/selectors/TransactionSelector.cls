/* TransactionSelector.cls */
public inherited sharing class TransactionSelector extends fflib_SObjectSelector {

    /* 1. sObjectField list */
    private List<String> additionalSObjectFieldList = new List<String>{
        'Id',
        'Name',
        'Shared_Asset__c',
        'Type__c',
        'Direction__c',
        'Amount__c',
        'Transaction_Date__c'
    };

    /* 2. Boilerplate code */
    public static TransactionSelector newInstance() {
        return (TransactionSelector) ITBA_Application_UTIL.selector.newInstance(
            Transaction__c.SObjectType
        );
    }

    public Schema.SObjectType getSObjectType() {
        return Transaction__c.SObjectType;
    }

    public fflib_QueryFactory getQueryFactory() {
        return new fflib_QueryFactory(getSObjectType());
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Transaction__c.Id,
            Transaction__c.Name,
            Transaction__c.Shared_Asset__c,
            Transaction__c.Type__c,
            Transaction__c.Direction__c,
            Transaction__c.Amount__c,
            Transaction__c.Transaction_Date__c
        };
    }

    public override Set<String> getRelatedFieldSet(){
        return new Set<String>{
            'Shared_Asset__c.Name'
        };
    }

    @TestVisible
    private List<Schema.SObjectField> getAdditionalSObjectFieldList() {
        return new List<Schema.SObjectField>{};
    }

    /* 3. Selector Methods */
    public List<Transaction__c> selectByIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Id IN :idSet');
        return (List<Transaction__c>) Database.query(queryFactory.toSOQL());
    }
}
