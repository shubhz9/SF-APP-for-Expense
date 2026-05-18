@IsTest
private class LoanServiceTest {
    @IsTest
    static void defaultsOutstandingPrincipalAndStatus() {
        Shared_Asset__c asset = createAsset();

        Test.startTest();
        Loan__c loan = new Loan__c(
            Shared_Asset__c = asset.Id,
            Principal_Amount__c = 1000,
            Interest_Rate__c = 8.5,
            EMI_Amount__c = 100,
            Start_Date__c = Date.today()
        );
        insert loan;
        Test.stopTest();

        loan = [
            SELECT Outstanding_Principal__c, Status__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];
        System.assertEquals(1000, loan.Outstanding_Principal__c, 'Outstanding principal should default to principal.');
        System.assertEquals('Active', loan.Status__c, 'Loan should default to Active.');
    }

    @IsTest
    static void blocksInvalidLoanValues() {
        Shared_Asset__c asset = createAsset();

        Database.SaveResult result = Database.insert(
            new Loan__c(
                Shared_Asset__c = asset.Id,
                Principal_Amount__c = -1,
                Outstanding_Principal__c = 200,
                Interest_Rate__c = 101,
                EMI_Amount__c = 0,
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(-1)
            ),
            false
        );

        System.assertEquals(false, result.isSuccess(), 'Invalid loan values should be blocked.');
    }

    @IsTest
    static void blocksClosedLoanWithOutstandingPrincipal() {
        Shared_Asset__c asset = createAsset();

        Database.SaveResult result = Database.insert(
            new Loan__c(
                Shared_Asset__c = asset.Id,
                Principal_Amount__c = 1000,
                Outstanding_Principal__c = 100,
                Status__c = 'Closed'
            ),
            false
        );

        System.assertEquals(false, result.isSuccess(), 'Closed loans cannot retain outstanding principal.');
    }

    @IsTest
    static void blocksInvalidLoanUpdate() {
        Shared_Asset__c asset = createAsset();
        Loan__c loan = new Loan__c(
            Shared_Asset__c = asset.Id,
            Principal_Amount__c = 1000,
            Outstanding_Principal__c = 1000,
            Status__c = 'Active'
        );
        insert loan;

        loan.Outstanding_Principal__c = 1200;
        Database.SaveResult result = Database.update(loan, false);

        System.assertEquals(false, result.isSuccess(), 'Outstanding principal cannot exceed principal on update.');
    }

    @IsTest
    static void domainFactoryConstructsLoanDomain() {
        Shared_Asset__c asset = createAsset();
        LoanDomain.ILoans domain = LoanDomain.newInstance(
            new List<Loan__c>{
                new Loan__c(
                    Shared_Asset__c = asset.Id,
                    Principal_Amount__c = 500,
                    Outstanding_Principal__c = 500,
                    Status__c = 'Active'
                )
            }
        );

        Test.startTest();
        domain.validateLoans();
        Test.stopTest();

        System.assertNotEquals(null, domain, 'Domain factory should construct LoanDomain.');
    }

    @IsTest
    static void domainFactoryConstructsLoanDomainFromIds() {
        Shared_Asset__c asset = createAsset();
        Loan__c loan = new Loan__c(
            Shared_Asset__c = asset.Id,
            Principal_Amount__c = 500,
            Outstanding_Principal__c = 500,
            Status__c = 'Active'
        );
        insert loan;

        LoanDomain.ILoans domain = LoanDomain.newInstance(new Set<Id>{ loan.Id });

        System.assertNotEquals(null, domain, 'Domain factory should construct LoanDomain from ids.');
    }

    private static Shared_Asset__c createAsset() {
        Shared_Asset__c asset = new Shared_Asset__c(
            Name = 'Shared Vehicle',
            Category__c = 'Car',
            Purchase_Date__c = Date.today(),
            Purchase_Price__c = 1000,
            Current_Value__c = 1000,
            Status__c = 'Active'
        );
        insert asset;
        return asset;
    }
}
