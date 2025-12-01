/* LoanInstallmentSelector.cls */
public inherited sharing class LoanInstallmentSelector extends fflib_SObjectSelector {

    /* 1. sObjectField list */
    private List<String> additionalSObjectFieldList = new List<String>{
        'Id',
        'Name',
        'Loan__c',
        'Due_Date__c',
        'Amount__c',
        'Principal_Component__c',
        'Interest_Component__c',
        'Status__c',
        'Paid_Date__c'
    };

    /* 2. Boilerplate code */
    public static LoanInstallmentSelector newInstance() {
        return (LoanInstallmentSelector) ITBA_Application_UTIL.selector.newInstance(
            Loan_Installment__c.SObjectType
        );
    }

    public Schema.SObjectType getSObjectType() {
        return Loan_Installment__c.SObjectType;
    }

    public fflib_QueryFactory getQueryFactory() {
        return new fflib_QueryFactory(getSObjectType());
    }

    public List<Schema.SObjectField> getSObjectFieldList() {
        return new List<Schema.SObjectField>{
            Loan_Installment__c.Id,
            Loan_Installment__c.Name,
            Loan_Installment__c.Loan__c,
            Loan_Installment__c.Due_Date__c,
            Loan_Installment__c.Amount__c,
            Loan_Installment__c.Principal_Component__c,
            Loan_Installment__c.Interest_Component__c,
            Loan_Installment__c.Status__c,
            Loan_Installment__c.Paid_Date__c
        };
    }

    public override Set<String> getRelatedFieldSet(){
        return new Set<String>{
            'Loan__c.Name'
        };
    }

    @TestVisible
    private List<Schema.SObjectField> getAdditionalSObjectFieldList() {
        return new List<Schema.SObjectField>{};
    }

    /* 3. Selector Methods */
    public List<Loan_Installment__c> selectByIds(Set<Id> idSet) {
        fflib_QueryFactory queryFactory = newQueryFactory(false, false, true, true);
        queryFactory.setCondition('Id IN :idSet');
        return (List<Loan_Installment__c>) Database.query(queryFactory.toSOQL());
    }
}
