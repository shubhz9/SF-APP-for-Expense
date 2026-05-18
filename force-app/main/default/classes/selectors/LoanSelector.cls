/* LoanSelector.cls */
public inherited sharing class LoanSelector extends fflib_SObjectSelector {

    /* 1. sObjectField list */
    private List<String> additionalSObjectFieldList = new List<String>{
        'Id',
        'Name',
        'Shared_Asset__c',
        'Principal_Amount__c',
        'Outstanding_Principal__c',
        'Interest_Rate__c',
        'Start_Date__c',
        'End_Date__c',
        'Status__c',
        'EMI_Amount__c'
    };

    /* 2. Boilerplate code */
    public static LoanSelector newInstance() {
        return (LoanSelector) ITBA_Application_UTIL.selector.newInstance(
            Loan__c.SObjectType
        );
    }

    public Schema.SObjectType getSObjectType() {
        return Loan__c.SObjectType;
    }

    public fflib_QueryFactory getQueryFactory() {
        return new fflib_QueryFactory(getSObjectType());
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Loan__c.Id,
            Loan__c.Name,
            Loan__c.Shared_Asset__c,
            Loan__c.Principal_Amount__c,
            Loan__c.Outstanding_Principal__c,
            Loan__c.Interest_Rate__c,
            Loan__c.Start_Date__c,
            Loan__c.End_Date__c,
            Loan__c.Status__c,
            Loan__c.EMI_Amount__c
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
    public List<Loan__c> selectByIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Id IN :idSet');
        return (List<Loan__c>) Database.query(queryFactory.toSOQL());
    }
}
