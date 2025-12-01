/**
 * @description       : 
 * @author            : Shubham Raut
 * @date              : 12-01-2025
 * @group             : ITBA
 * @last modified on  : 12-01-2025
 * @last modified by  : Shubham Raut
 * Modifications Log
 * Ver   Date         Author         Modification
 * 1.0   11-27-2025   Shubham Raut   Initial Version
**/
public inherited sharing class TransactionDomain extends fflib_SObjectDomain implements ITransactions {

    public interface ITransactions{
        void validateTransactions();
        void validateTransactions(List<Transaction__c> transactions);
    }

    public static ITransactions newInstance(List<Transaction__c> records) {
        return (ITransactions) ITBA_Application_UTIL.domain.newInstance(records);
    }

    public static ITransactions newInstance(Set<Id> recordIds) {
        return (ITransactions) ITBA_Application_UTIL.domain.newInstance(recordIds);
    }

    public TransactionDomain(List<Transaction__c> records) {
        super(records);
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new TransactionDomain((List<Transaction__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        this.validateTransactions((List<Transaction__c>) getRecords());
    }

    public override void onAfterInsert(){

    }

    public override void onAfterUpdate(){
        
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        // Example: only validate when specific fields change
        
        Set<String> changedFields = new Set<String>{ 'Type__c', 'Amount__c', 'Shared_Asset__c' };
        this.validateTransactions((List<Transaction__c>) getChangedRecords(changedFields));
    }

    public void validateTransactions() {
        validateTransactions((List<Transaction__c>) getRecords());
    }

    public void validateTransactions(List<Transaction__c> transactions) {
        if (transactions == null || transactions.isEmpty()) return;
    }
}
