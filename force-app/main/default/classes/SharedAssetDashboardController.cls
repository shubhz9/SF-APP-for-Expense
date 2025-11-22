public with sharing class SharedAssetDashboardController {

    public class ParticipantDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal ownershipPercentage;
        @AuraEnabled public Decimal loanSharePercentage;
        @AuraEnabled public Decimal totalEquity;
        @AuraEnabled public Decimal totalLoanPaid;
        @AuraEnabled public Decimal totalIncome;
        @AuraEnabled public Decimal totalExpense;
        @AuraEnabled public Decimal netPosition;
    }

    public class AssetSummaryDTO {
        @AuraEnabled public Id assetId;
        @AuraEnabled public String assetName;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal totalEquity;
        @AuraEnabled public Decimal totalLoanTaken;
        @AuraEnabled public Decimal outstandingLoan;
        @AuraEnabled public Decimal totalIncome;
        @AuraEnabled public Decimal totalExpenses;
        @AuraEnabled public Decimal netCashflow;
        @AuraEnabled public List<ParticipantDTO> participants;
    }

    @AuraEnabled(cacheable=true)
    public static AssetSummaryDTO getAssetSummary(Id assetId) {
        if (assetId == null) {
            return null;
        }

        Shared_Asset__c asset = [
            SELECT Id,
                   Name,
                   Total_Cost__c,
                   Total_Equity_Contributed__c,
                   Total_Loan_Taken__c,
                   Outstanding_Loan__c,
                   Total_Income__c,
                   Total_Expenses__c,
                   Net_Cashflow__c
            FROM Shared_Asset__c
            WHERE Id = :assetId
            LIMIT 1
        ];

        List<Asset_Participant__c> participants = [
            SELECT Id,
                   Shared_Asset__c,
                   Ownership_Percentage__c,
                   Loan_Share_Percentage__c,
                   Total_Equity_Contributed__c,
                   Total_Loan_Paid__c,
                   Total_Income_Share__c,
                   Total_Expense_Share__c,
                   Net_Position__c,
                   User__c,
                   User__r.Name,
                   Contact__c,
                   Contact__r.Name
            FROM Asset_Participant__c
            WHERE Shared_Asset__c = :assetId
            ORDER BY CreatedDate
        ];

        AssetSummaryDTO dto = new AssetSummaryDTO();
        dto.assetId = asset.Id;
        dto.assetName = asset.Name;
        dto.totalCost = asset.Total_Cost__c;
        dto.totalEquity = asset.Total_Equity_Contributed__c;
        dto.totalLoanTaken = asset.Total_Loan_Taken__c;
        dto.outstandingLoan = asset.Outstanding_Loan__c;
        dto.totalIncome = asset.Total_Income__c;
        dto.totalExpenses = asset.Total_Expenses__c;
        dto.netCashflow = asset.Net_Cashflow__c;
        dto.participants = new List<ParticipantDTO>();

        for (Asset_Participant__c ap : participants) {
            ParticipantDTO p = new ParticipantDTO();
            p.id = ap.Id;
            p.ownershipPercentage = ap.Ownership_Percentage__c;
            p.loanSharePercentage = ap.Loan_Share_Percentage__c;
            p.totalEquity = ap.Total_Equity_Contributed__c;
            p.totalLoanPaid = ap.Total_Loan_Paid__c;
            p.totalIncome = ap.Total_Income_Share__c;
            p.totalExpense = ap.Total_Expense_Share__c;
            p.netPosition = ap.Net_Position__c;

            if (ap.User__c != null) {
                p.name = ap.User__r.Name;
            } else if (ap.Contact__c != null) {
                p.name = ap.Contact__r.Name;
            } else {
                p.name = 'Unknown';
            }

            dto.participants.add(p);
        }

        return dto;
    }
}