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

    private Map<Id, Transaction__c> oldTransactionsById;

    public static ITransactions newInstance(List<Transaction__c> records) {
        return (ITransactions) ITBA_Application_UTIL.domain.newInstance(records);
    }

    public static ITransactions newInstance(Set<Id> recordIds) {
        return (ITransactions) ITBA_Application_UTIL.domain.newInstance(recordIds);
    }

    public TransactionDomain(List<Transaction__c> records) {
        super(records);
    }

    public TransactionDomain(List<Transaction__c> records, Map<Id, Transaction__c> oldTransactionsById) {
        super(records);
        this.oldTransactionsById = oldTransactionsById;
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new TransactionDomain((List<Transaction__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        TransactionService service = new TransactionService();
        service.applyDirection((List<Transaction__c>) getRecords());
        service.prepareRelatedRecords((List<Transaction__c>) getRecords());
        this.validateTransactions((List<Transaction__c>) getRecords());
    }

    public override void onAfterInsert(){
        TransactionService service = new TransactionService();
        service.processIncomeAndReturnTransactions((List<Transaction__c>) getRecords());
        service.processProfitDistributionTransactions((List<Transaction__c>) getRecords());
        service.refreshRelatedRollups((List<Transaction__c>) getRecords(), (Map<Id, Transaction__c>) null);
    }

    public void onAfterUpdate(){
        this.onAfterUpdate(this.getOldRecordsAsSObjects());
    }

    public override void onAfterUpdate(Map<Id, SObject> existingRecords){
        TransactionService service = new TransactionService();
        service.processIncomeAndReturnTransactions(
            (List<Transaction__c>) getRecords(),
            this.getOldTransactionsById(existingRecords)
        );
        service.processProfitDistributionTransactions(
            (List<Transaction__c>) getRecords(),
            this.getOldTransactionsById(existingRecords)
        );
        service.refreshRelatedRollups(
            (List<Transaction__c>) getRecords(),
            this.getOldTransactionsById(existingRecords)
        );
    }

    public override void onAfterDelete(){
        TransactionService service = new TransactionService();
        service.refreshRelatedRollups((List<Transaction__c>) null, (List<Transaction__c>) getRecords());
    }

    public void onBeforeUpdate() {
        this.onBeforeUpdate(this.getOldRecordsAsSObjects());
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        TransactionService service = new TransactionService();
        service.applyDirection((List<Transaction__c>) getRecords());
        service.prepareRelatedRecords((List<Transaction__c>) getRecords());
        this.validateTransactions(this.getChangedTransactions(existingRecords));
    }

    public void validateTransactions() {
        validateTransactions((List<Transaction__c>) getRecords());
    }

    public void validateTransactions(List<Transaction__c> transactions) {
        if (transactions == null || transactions.isEmpty()) return;

        for (Transaction__c txn : transactions) {
            if (txn.Amount__c == null || txn.Amount__c <= 0) {
                txn.Amount__c.addError('Transaction amount must be greater than zero.');
            }

            if (String.isBlank(txn.Type__c)) {
                txn.Type__c.addError('Transaction type is required.');
                continue;
            }

            if (TransactionService.requiresOwner(txn.Type__c) && txn.Owner__c == null) {
                txn.Owner__c.addError('Owner is required for this transaction type.');
            }

            if (TransactionService.requiresLoan(txn.Type__c) && txn.Loan__c == null) {
                txn.Loan__c.addError('Loan is required for this transaction type.');
            }

            if (txn.Loan_Installment__c != null && txn.Loan__c == null) {
                txn.Loan__c.addError('Loan is required when a loan installment is selected.');
            }
        }
    }

    private List<Transaction__c> getChangedTransactions(Map<Id, SObject> existingRecords) {
        List<Transaction__c> changedTransactions = new List<Transaction__c>();
        Map<Id, Transaction__c> typedExistingRecords = this.getOldTransactionsById(existingRecords);
        if (typedExistingRecords == null || typedExistingRecords.isEmpty()) {
            return changedTransactions;
        }

        for (Transaction__c txn : (List<Transaction__c>) getRecords()) {
            Transaction__c oldTxn = typedExistingRecords.get(txn.Id);
            if (oldTxn == null) {
                continue;
            }

            if (txn.Type__c != oldTxn.Type__c ||
                txn.Amount__c != oldTxn.Amount__c ||
                txn.Shared_Asset__c != oldTxn.Shared_Asset__c ||
                txn.Owner__c != oldTxn.Owner__c ||
                txn.Loan__c != oldTxn.Loan__c ||
                txn.Loan_Installment__c != oldTxn.Loan_Installment__c) {
                changedTransactions.add(txn);
            }
        }

        return changedTransactions;
    }

    private Map<Id, SObject> getOldRecordsAsSObjects() {
        Map<Id, SObject> typedOldRecords = new Map<Id, SObject>();
        if (this.oldTransactionsById == null) {
            return typedOldRecords;
        }

        for (Id txnId : this.oldTransactionsById.keySet()) {
            typedOldRecords.put(txnId, this.oldTransactionsById.get(txnId));
        }

        return typedOldRecords;
    }

    private Map<Id, Transaction__c> getOldTransactionsById(Map<Id, SObject> existingRecords) {
        if (this.oldTransactionsById != null) {
            return this.oldTransactionsById;
        }

        Map<Id, Transaction__c> typedExistingRecords = new Map<Id, Transaction__c>();
        if (existingRecords == null) {
            return typedExistingRecords;
        }

        for (Id txnId : existingRecords.keySet()) {
            typedExistingRecords.put(txnId, (Transaction__c) existingRecords.get(txnId));
        }

        return typedExistingRecords;
    }
}
