import { LightningElement, api, track } from 'lwc';

export default class CashflowQuickEntry extends LightningElement {
    @api recordId; // Shared_Asset__c Id if placed on asset record page

    @track successMessage;
    @track errorMessage;

    handleSuccess(event) {
        this.errorMessage = undefined;
        this.successMessage = 'Cashflow created successfully. Allocations will be created by Flow.';
    }

    handleError(event) {
        this.successMessage = undefined;
        this.errorMessage = 'Error creating cashflow: ' + (event.detail ? event.detail.message : 'Unknown error');
    }
}