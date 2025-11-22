import { LightningElement, api, wire, track } from 'lwc';
import getAssetSummary from '@salesforce/apex/SharedAssetDashboardController.getAssetSummary';

export default class SharedAssetDashboard extends LightningElement {
    @api recordId; // expected to be Shared_Asset__c Id

    @track assetSummary;
    @track error;
    @track isLoading = true;

    @wire(getAssetSummary, { assetId: '$recordId' })
    wiredSummary({ error, data }) {
        this.isLoading = false;
        if (data) {
            this.assetSummary = data;
            this.error = undefined;
        } else if (error) {
            // Simple error string
            this.error = error.body ? error.body.message : error.message;
            this.assetSummary = undefined;
        }
    }
}