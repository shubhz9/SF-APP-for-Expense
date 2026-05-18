/* PayoutSelector.cls */
public inherited sharing class PayoutSelector extends fflib_SObjectSelector {


    
    /* 1. sObjectField list */
    private List<String> additionalSObjectFieldList = new List<String>{
        'Id',
        'Name',
        'Transaction__c',
        'Ownership_Percentage__c',
        'Amount__c',
        'Is_Paid__c',
        'Payment_Transaction__c',
        'Owner__c',
        'Remarks__c'
    };

    /* 2. Boilerplate code */
    public static PayoutSelector newInstance() {
        return (PayoutSelector) ITBA_Application_UTIL.selector.newInstance(
            Payout__c.SObjectType
        );
    }

    public Schema.SObjectType getSObjectType() {
        return Payout__c.SObjectType;
    }

    public fflib_QueryFactory getQueryFactory() {
        return new fflib_QueryFactory(getSObjectType());
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Payout__c.Id,
            Payout__c.Name,
            Payout__c.Transaction__c,
            Payout__c.Ownership_Percentage__c,
            Payout__c.Amount__c,
            Payout__c.Is_Paid__c,
            Payout__c.Payment_Transaction__c,
            Payout__c.Owner__c,
            Payout__c.Remarks__c
        };
    }

    public override Set<String> getRelatedFieldSet(){
        return new Set<String>{
            'Owner__c.Name'
        };
    }

    @TestVisible
    private List<Schema.SObjectField> getAdditionalSObjectFieldList() {
        return new List<Schema.SObjectField>{};
    }

    /* 3. Selector Methods */
    public List<Payout__c> selectByIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true ,true);
        queryFactory.setCondition('Id IN :idSet');
        return (List<Payout__c>) Database.query(queryFactory.toSOQL());
    }

    public List<Payout__c> selectByTransactionIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true ,true);
        queryFactory.setCondition('Transaction__c IN :idSet');
        return (List<Payout__c>) Database.query(queryFactory.toSOQL());
    }

}
