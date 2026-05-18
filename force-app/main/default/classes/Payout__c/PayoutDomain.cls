public inherited sharing class PayoutDomain extends fflib_SObjectDomain implements IPayouts {
    public interface IPayouts {
        void validatePayouts();
        void validatePayouts(List<Payout__c> payouts);
    }

    private Map<Id, Payout__c> oldPayoutsById;

    public static IPayouts newInstance(List<Payout__c> records) {
        return (IPayouts) ITBA_Application_UTIL.domain.newInstance(records);
    }

    public static IPayouts newInstance(Set<Id> recordIds) {
        return (IPayouts) ITBA_Application_UTIL.domain.newInstance(recordIds);
    }

    public PayoutDomain(List<Payout__c> records) {
        super(records);
    }

    public PayoutDomain(List<Payout__c> records, Map<Id, Payout__c> oldPayoutsById) {
        super(records);
        this.oldPayoutsById = oldPayoutsById;
    }

    public class Constructor implements fflib_SObjectDomain.IConstructable {
        public fflib_SObjectDomain construct(List<SObject> sObjectList) {
            return new PayoutDomain((List<Payout__c>) sObjectList);
        }
    }

    public override void onBeforeInsert() {
        validatePayouts((List<Payout__c>) getRecords());
    }

    public void onBeforeUpdate() {
        this.onBeforeUpdate(getOldRecordsAsSObjects());
    }

    public override void onBeforeUpdate(Map<Id, SObject> existingRecords) {
        new PayoutService().validatePayouts(
            getChangedPayouts(existingRecords),
            getOldPayoutsById(existingRecords)
        );
    }

    public void validatePayouts() {
        validatePayouts((List<Payout__c>) getRecords());
    }

    public void validatePayouts(List<Payout__c> payouts) {
        new PayoutService().validatePayouts(payouts);
    }

    private List<Payout__c> getChangedPayouts(Map<Id, SObject> existingRecords) {
        List<Payout__c> changedPayouts = new List<Payout__c>();
        Map<Id, Payout__c> typedExistingRecords = getOldPayoutsById(existingRecords);
        if (typedExistingRecords == null || typedExistingRecords.isEmpty()) {
            return changedPayouts;
        }

        for (Payout__c payout : (List<Payout__c>) getRecords()) {
            Payout__c oldPayout = typedExistingRecords.get(payout.Id);
            if (oldPayout == null) {
                continue;
            }

            if (payout.Transaction__c != oldPayout.Transaction__c ||
                payout.Owner__c != oldPayout.Owner__c ||
                payout.Ownership_Percentage__c != oldPayout.Ownership_Percentage__c ||
                payout.Amount__c != oldPayout.Amount__c ||
                payout.Is_Paid__c != oldPayout.Is_Paid__c ||
                payout.Payment_Transaction__c != oldPayout.Payment_Transaction__c ||
                payout.Remarks__c != oldPayout.Remarks__c) {
                changedPayouts.add(payout);
            }
        }

        return changedPayouts;
    }

    private Map<Id, SObject> getOldRecordsAsSObjects() {
        Map<Id, SObject> typedOldRecords = new Map<Id, SObject>();
        if (this.oldPayoutsById == null) {
            return typedOldRecords;
        }

        for (Id payoutId : this.oldPayoutsById.keySet()) {
            typedOldRecords.put(payoutId, this.oldPayoutsById.get(payoutId));
        }

        return typedOldRecords;
    }

    private Map<Id, Payout__c> getOldPayoutsById(Map<Id, SObject> existingRecords) {
        if (this.oldPayoutsById != null) {
            return this.oldPayoutsById;
        }

        Map<Id, Payout__c> typedExistingRecords = new Map<Id, Payout__c>();
        if (existingRecords == null) {
            return typedExistingRecords;
        }

        for (Id payoutId : existingRecords.keySet()) {
            typedExistingRecords.put(payoutId, (Payout__c) existingRecords.get(payoutId));
        }

        return typedExistingRecords;
    }
}
