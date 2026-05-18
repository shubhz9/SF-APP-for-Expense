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
        'Transaction_Date__c',
        'Mode__c',
        'Owner__c',
        'Loan__c',
        'Loan_Installment__c',
        'Is_System_Generated__c',
        'Notes__c'
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
            Transaction__c.Transaction_Date__c,
            Transaction__c.Mode__c,
            Transaction__c.Owner__c,
            Transaction__c.Loan__c,
            Transaction__c.Loan_Installment__c,
            Transaction__c.Is_System_Generated__c,
            Transaction__c.Notes__c
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

    public List<Transaction__c> selectByLoans(Set<Id> loanIds) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Loan__c IN :loanIds');
        return (List<Transaction__c>) Database.query(queryFactory.toSOQL());
    }

    public List<Transaction__c> selectBySharedAssets(Set<Id> assetIds) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Shared_Asset__c IN :assetIds');
        return (List<Transaction__c>) Database.query(queryFactory.toSOQL());
    }
}
