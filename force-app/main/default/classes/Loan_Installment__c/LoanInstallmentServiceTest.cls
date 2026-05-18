@IsTest
private class LoanInstallmentServiceTest {
    @IsTest
    static void defaultsAmountStatusAndPaidDate() {
        Loan__c loan = createLoan();

        Test.startTest();
        Loan_Installment__c installment = new Loan_Installment__c(
            Loan__c = loan.Id,
            Due_Date__c = Date.today().addDays(10),
            Principal_Component__c = 80,
            Interest_Component__c = 20
        );
        insert installment;
        Test.stopTest();

        installment = [
            SELECT Amount__c, Status__c
            FROM Loan_Installment__c
            WHERE Id = :installment.Id
        ];
        System.assertEquals(100, installment.Amount__c, 'Amount should default from principal plus interest.');
        System.assertEquals('Planned', installment.Status__c, 'Installment should default to Planned.');

        installment.Status__c = 'Paid';
        update installment;

        installment = [
            SELECT Paid_Date__c
            FROM Loan_Installment__c
            WHERE Id = :installment.Id
        ];
        System.assertEquals(Date.today(), installment.Paid_Date__c, 'Paid installments should receive a paid date.');
    }

    @IsTest
    static void blocksInvalidInstallmentValues() {
        Loan__c loan = createLoan();

        Database.SaveResult result = Database.insert(
            new Loan_Installment__c(
                Loan__c = loan.Id,
                Amount__c = 100,
                Principal_Component__c = 80,
                Interest_Component__c = 10,
                Paid_Date__c = Date.today(),
                Status__c = 'Pending'
            ),
            false
        );

        System.assertEquals(false, result.isSuccess(), 'Invalid installment values should be blocked.');
    }

    @IsTest
    static void blocksInvalidInstallmentUpdate() {
        Loan__c loan = createLoan();
        Loan_Installment__c installment = new Loan_Installment__c(
            Loan__c = loan.Id,
            Due_Date__c = Date.today().addDays(10),
            Amount__c = 100,
            Principal_Component__c = 80,
            Interest_Component__c = 20,
            Status__c = 'Planned'
        );
        insert installment;

        installment.Interest_Component__c = -1;
        Database.SaveResult result = Database.update(installment, false);

        System.assertEquals(false, result.isSuccess(), 'Negative interest component should be blocked on update.');
    }

    @IsTest
    static void domainFactoryConstructsLoanInstallmentDomain() {
        Loan__c loan = createLoan();
        LoanInstallmentDomain.ILoanInstallments domain = LoanInstallmentDomain.newInstance(
            new List<Loan_Installment__c>{
                new Loan_Installment__c(
                    Loan__c = loan.Id,
                    Due_Date__c = Date.today().addDays(10),
                    Amount__c = 100,
                    Principal_Component__c = 80,
                    Interest_Component__c = 20,
                    Status__c = 'Planned'
                )
            }
        );

        Test.startTest();
        domain.validateInstallments();
        Test.stopTest();

        System.assertNotEquals(null, domain, 'Domain factory should construct LoanInstallmentDomain.');
    }

    @IsTest
    static void domainFactoryConstructsLoanInstallmentDomainFromIds() {
        Loan__c loan = createLoan();
        Loan_Installment__c installment = new Loan_Installment__c(
            Loan__c = loan.Id,
            Due_Date__c = Date.today().addDays(10),
            Amount__c = 100,
            Principal_Component__c = 80,
            Interest_Component__c = 20,
            Status__c = 'Planned'
        );
        insert installment;

        LoanInstallmentDomain.ILoanInstallments domain = LoanInstallmentDomain.newInstance(
            new Set<Id>{ installment.Id }
        );

        System.assertNotEquals(null, domain, 'Domain factory should construct LoanInstallmentDomain from ids.');
    }

    private static Loan__c createLoan() {
        Shared_Asset__c asset = new Shared_Asset__c(
            Name = 'Shared Vehicle',
            Category__c = 'Car',
            Purchase_Date__c = Date.today(),
            Purchase_Price__c = 1000,
            Current_Value__c = 1000,
            Status__c = 'Active'
        );
        insert asset;

        Loan__c loan = new Loan__c(
            Shared_Asset__c = asset.Id,
            Principal_Amount__c = 1000,
            Outstanding_Principal__c = 1000,
            Status__c = 'Active'
        );
        insert loan;
        return loan;
    }
}
