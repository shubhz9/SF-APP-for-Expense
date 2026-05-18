@IsTest
private class TransactionServiceTest {
    @IsTest
    static void createsAndRegeneratesPayoutsForIncomeTransactions() {
        TestData data = createAssetWithOwners();

        Test.startTest();
        Transaction__c incomeTxn = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Type__c = 'Income_From_Asset',
            Amount__c = 1000,
            Transaction_Date__c = System.now()
        );
        insert incomeTxn;
        Test.stopTest();

        incomeTxn = [
            SELECT Direction__c
            FROM Transaction__c
            WHERE Id = :incomeTxn.Id
        ];
        System.assertEquals('Inward', incomeTxn.Direction__c, 'Income transactions should be marked inward.');

        List<Payout__c> payouts = [
            SELECT Owner__c, Ownership_Percentage__c, Amount__c, Is_Paid__c
            FROM Payout__c
            WHERE Transaction__c = :incomeTxn.Id
            ORDER BY Amount__c
        ];
        System.assertEquals(2, payouts.size(), 'Income should create one payout per active owner.');
        System.assertEquals(400, payouts[0].Amount__c, 'Minority owner should receive 40%.');
        System.assertEquals(600, payouts[1].Amount__c, 'Majority owner should receive 60%.');
        System.assertEquals(false, payouts[0].Is_Paid__c, 'Generated payouts should start unpaid.');

        incomeTxn.Amount__c = 2000;
        update incomeTxn;

        payouts = [
            SELECT Amount__c
            FROM Payout__c
            WHERE Transaction__c = :incomeTxn.Id
            ORDER BY Amount__c
        ];
        System.assertEquals(2, payouts.size(), 'Changed income should regenerate, not duplicate, payouts.');
        System.assertEquals(800, payouts[0].Amount__c);
        System.assertEquals(1200, payouts[1].Amount__c);
    }

    @IsTest
    static void rollsUpOwnerContributionsAndHandlesDelete() {
        TestData data = createAssetWithOwners();

        Transaction__c ownerOneContribution = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Owner__c = data.ownerOne.Id,
            Type__c = 'Down_Payment',
            Amount__c = 300,
            Transaction_Date__c = System.now()
        );
        Transaction__c ownerTwoContribution = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Owner__c = data.ownerTwo.Id,
            Type__c = 'Owner_Contribution',
            Amount__c = 700,
            Transaction_Date__c = System.now()
        );

        Test.startTest();
        insert new List<Transaction__c>{ ownerOneContribution, ownerTwoContribution };
        Test.stopTest();

        Map<Id, Asset_Ownership__c> ownershipByOwnerId = getOwnershipByOwnerId(data.asset.Id);
        System.assertEquals(300, ownershipByOwnerId.get(data.ownerOne.Id).Total_Contribution__c);
        System.assertEquals(700, ownershipByOwnerId.get(data.ownerTwo.Id).Total_Contribution__c);

        delete ownerTwoContribution;

        ownershipByOwnerId = getOwnershipByOwnerId(data.asset.Id);
        System.assertEquals(300, ownershipByOwnerId.get(data.ownerOne.Id).Total_Contribution__c);
        System.assertEquals(0, ownershipByOwnerId.get(data.ownerTwo.Id).Total_Contribution__c);
    }

    @IsTest
    static void rollsUpLoanAndInstallmentState() {
        Shared_Asset__c asset = createAsset();
        Loan__c loan = new Loan__c(
            Name = 'Vehicle Loan',
            Shared_Asset__c = asset.Id,
            Principal_Amount__c = 1000,
            Outstanding_Principal__c = 1000,
            Status__c = 'Active'
        );
        insert loan;

        Loan_Installment__c installment = new Loan_Installment__c(
            Name = 'Installment 1',
            Loan__c = loan.Id,
            Due_Date__c = Date.today().addDays(5),
            Amount__c = 300,
            Principal_Component__c = 200,
            Interest_Component__c = 100,
            Status__c = 'Planned'
        );
        insert installment;

        Transaction__c repayment = new Transaction__c(
            Shared_Asset__c = asset.Id,
            Loan__c = loan.Id,
            Loan_Installment__c = installment.Id,
            Type__c = 'Loan_Repayment',
            Amount__c = 200,
            Transaction_Date__c = System.now()
        );
        Transaction__c interest = new Transaction__c(
            Shared_Asset__c = asset.Id,
            Loan__c = loan.Id,
            Loan_Installment__c = installment.Id,
            Type__c = 'Interest_Payment',
            Amount__c = 100,
            Transaction_Date__c = System.now()
        );

        Test.startTest();
        insert new List<Transaction__c>{ repayment, interest };
        Test.stopTest();

        loan = [
            SELECT Outstanding_Principal__c, Status__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];
        installment = [
            SELECT Status__c, Paid_Date__c
            FROM Loan_Installment__c
            WHERE Id = :installment.Id
        ];
        System.assertEquals(800, loan.Outstanding_Principal__c, 'Only principal repayments reduce outstanding principal.');
        System.assertEquals('Active', loan.Status__c);
        System.assertEquals('Paid', installment.Status__c, 'Principal plus interest should satisfy the installment amount.');
        System.assertNotEquals(null, installment.Paid_Date__c);

        repayment.Amount__c = 1000;
        update repayment;

        loan = [
            SELECT Outstanding_Principal__c, Status__c
            FROM Loan__c
            WHERE Id = :loan.Id
        ];
        System.assertEquals(0, loan.Outstanding_Principal__c);
        System.assertEquals('Closed', loan.Status__c);
    }

    @IsTest
    static void createsLoanFromLoanDisbursementTransaction() {
        Shared_Asset__c asset = createAsset();

        Test.startTest();
        Transaction__c disbursement = new Transaction__c(
            Shared_Asset__c = asset.Id,
            Type__c = 'Loan_Disbursement',
            Amount__c = 2500,
            Transaction_Date__c = System.now()
        );
        insert disbursement;
        Test.stopTest();

        disbursement = [
            SELECT Loan__c, Direction__c
            FROM Transaction__c
            WHERE Id = :disbursement.Id
        ];
        System.assertNotEquals(null, disbursement.Loan__c, 'Loan disbursement should create and link a loan.');
        System.assertEquals('Inward', disbursement.Direction__c);

        Loan__c loan = [
            SELECT Shared_Asset__c, Principal_Amount__c, Outstanding_Principal__c, Status__c
            FROM Loan__c
            WHERE Id = :disbursement.Loan__c
        ];
        System.assertEquals(asset.Id, loan.Shared_Asset__c);
        System.assertEquals(2500, loan.Principal_Amount__c);
        System.assertEquals(2500, loan.Outstanding_Principal__c);
        System.assertEquals('Active', loan.Status__c);
    }

    @IsTest
    static void createsInstallmentFromLoanPaymentTransaction() {
        Shared_Asset__c asset = createAsset();
        Loan__c loan = new Loan__c(
            Shared_Asset__c = asset.Id,
            Principal_Amount__c = 1000,
            Outstanding_Principal__c = 1000,
            Status__c = 'Active'
        );
        insert loan;

        Test.startTest();
        Transaction__c repayment = new Transaction__c(
            Shared_Asset__c = asset.Id,
            Loan__c = loan.Id,
            Type__c = 'Loan_Repayment',
            Amount__c = 250,
            Transaction_Date__c = System.now()
        );
        insert repayment;
        Test.stopTest();

        repayment = [
            SELECT Loan_Installment__c
            FROM Transaction__c
            WHERE Id = :repayment.Id
        ];
        System.assertNotEquals(null, repayment.Loan_Installment__c, 'Loan payment should create and link an installment.');

        Loan_Installment__c installment = [
            SELECT Loan__c, Amount__c, Principal_Component__c, Interest_Component__c, Status__c, Paid_Date__c
            FROM Loan_Installment__c
            WHERE Id = :repayment.Loan_Installment__c
        ];
        System.assertEquals(loan.Id, installment.Loan__c);
        System.assertEquals(250, installment.Amount__c);
        System.assertEquals(250, installment.Principal_Component__c);
        System.assertEquals(0, installment.Interest_Component__c);
        System.assertEquals('Paid', installment.Status__c);
        System.assertNotEquals(null, installment.Paid_Date__c);
    }

    @IsTest
    static void profitDistributionTransactionMarksMatchingPayoutPaid() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Type__c = 'Income_From_Asset',
            Amount__c = 1000,
            Transaction_Date__c = System.now()
        );
        insert incomeTxn;

        Payout__c payout = [
            SELECT Id, Amount__c, Is_Paid__c, Payment_Transaction__c
            FROM Payout__c
            WHERE Transaction__c = :incomeTxn.Id
                AND Owner__c = :data.ownerOne.Id
            LIMIT 1
        ];
        System.assertEquals(false, payout.Is_Paid__c);

        Test.startTest();
        Transaction__c paymentTxn = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Owner__c = data.ownerOne.Id,
            Type__c = 'Profit_Distribution',
            Amount__c = payout.Amount__c,
            Transaction_Date__c = System.now()
        );
        insert paymentTxn;
        Test.stopTest();

        payout = [
            SELECT Is_Paid__c, Payment_Transaction__c
            FROM Payout__c
            WHERE Id = :payout.Id
        ];
        System.assertEquals(true, payout.Is_Paid__c, 'Profit distribution should mark a matching payout paid.');
        System.assertEquals(paymentTxn.Id, payout.Payment_Transaction__c);
    }

    @IsTest
    static void validatesAmountOwnerAndLoanRequirements() {
        Shared_Asset__c asset = createAsset();

        Database.SaveResult contributionResult = Database.insert(
            new Transaction__c(
                Shared_Asset__c = asset.Id,
                Type__c = 'Owner_Contribution',
                Amount__c = 100,
                Transaction_Date__c = System.now()
            ),
            false
        );
        System.assertEquals(false, contributionResult.isSuccess(), 'Owner contribution should require an owner.');

        Database.SaveResult loanResult = Database.insert(
            new Transaction__c(
                Shared_Asset__c = asset.Id,
                Type__c = 'Loan_Repayment',
                Amount__c = 100,
                Transaction_Date__c = System.now()
            ),
            false
        );
        System.assertEquals(false, loanResult.isSuccess(), 'Loan repayment should require a loan.');

        Contact owner = new Contact(LastName = 'Validation Owner');
        insert owner;
        Database.SaveResult amountResult = Database.insert(
            new Transaction__c(
                Shared_Asset__c = asset.Id,
                Owner__c = owner.Id,
                Type__c = 'Down_Payment',
                Amount__c = 0,
                Transaction_Date__c = System.now()
            ),
            false
        );
        System.assertEquals(false, amountResult.isSuccess(), 'Amount must be positive.');
    }

    @IsTest
    static void domainFactoryConstructsTransactionDomain() {
        Shared_Asset__c asset = createAsset();
        TransactionDomain.ITransactions domain = TransactionDomain.newInstance(
            new List<Transaction__c>{
                new Transaction__c(
                    Shared_Asset__c = asset.Id,
                    Type__c = 'Other_Income',
                    Amount__c = 10,
                    Transaction_Date__c = System.now()
                )
            }
        );

        Test.startTest();
        domain.validateTransactions();
        Test.stopTest();

        System.assertNotEquals(null, domain, 'Domain factory should construct the transaction domain.');
    }

    @IsTest
    static void domainFactoryConstructsTransactionDomainFromIds() {
        Shared_Asset__c asset = createAsset();
        Transaction__c txn = new Transaction__c(
            Shared_Asset__c = asset.Id,
            Type__c = 'Other_Income',
            Amount__c = 10,
            Transaction_Date__c = System.now()
        );
        insert txn;

        TransactionDomain.ITransactions domain = TransactionDomain.newInstance(new Set<Id>{ txn.Id });

        System.assertNotEquals(null, domain, 'Domain factory should construct transaction domain from ids.');
    }

    private static TestData createAssetWithOwners() {
        TestData data = new TestData();
        data.asset = createAsset();

        data.ownerOne = new Contact(LastName = 'Owner One');
        data.ownerTwo = new Contact(LastName = 'Owner Two');
        insert new List<Contact>{ data.ownerOne, data.ownerTwo };

        insert new List<Asset_Ownership__c>{
            new Asset_Ownership__c(
                Shared_Asset__c = data.asset.Id,
                Owner__c = data.ownerOne.Id,
                Ownership_Percentage__c = 60,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            ),
            new Asset_Ownership__c(
                Shared_Asset__c = data.asset.Id,
                Owner__c = data.ownerTwo.Id,
                Ownership_Percentage__c = 40,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            )
        };

        return data;
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

    private static Map<Id, Asset_Ownership__c> getOwnershipByOwnerId(Id assetId) {
        Map<Id, Asset_Ownership__c> ownershipByOwnerId = new Map<Id, Asset_Ownership__c>();
        for (Asset_Ownership__c ownership : [
            SELECT Owner__c, Total_Contribution__c
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c = :assetId
        ]) {
            ownershipByOwnerId.put(ownership.Owner__c, ownership);
        }
        return ownershipByOwnerId;
    }

    private class TestData {
        Shared_Asset__c asset;
        Contact ownerOne;
        Contact ownerTwo;
    }
}
