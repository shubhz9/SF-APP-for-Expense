@IsTest
private class PayoutServiceTest {
    @IsTest
    static void allowsGeneratedPayoutFromIncomeTransaction() {
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

        List<Payout__c> payouts = [
            SELECT Owner__c, Ownership_Percentage__c, Amount__c, Is_Paid__c
            FROM Payout__c
            WHERE Transaction__c = :incomeTxn.Id
        ];
        System.assertEquals(2, payouts.size(), 'Income transaction should create payout allocations.');
    }

    @IsTest
    static void blocksInvalidPayoutValues() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = createIncomeTransaction(data.asset.Id);

        Database.SaveResult result = Database.insert(
            new Payout__c(
                Transaction__c = incomeTxn.Id,
                Amount__c = 0,
                Ownership_Percentage__c = 101,
                Is_Paid__c = true
            ),
            false
        );

        System.assertEquals(false, result.isSuccess(), 'Invalid payout values should be blocked.');
    }

    @IsTest
    static void allowsValidPaymentTransaction() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = createIncomeTransaction(data.asset.Id);
        Payout__c payout = new Payout__c(
            Transaction__c = incomeTxn.Id,
            Owner__c = data.ownerOne.Id,
            Amount__c = 300,
            Ownership_Percentage__c = 60,
            Is_Paid__c = false
        );
        insert payout;

        Transaction__c paymentTxn = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Owner__c = data.ownerOne.Id,
            Type__c = 'Profit_Distribution',
            Amount__c = 300,
            Transaction_Date__c = System.now()
        );
        insert paymentTxn;

        Test.startTest();
        payout.Is_Paid__c = true;
        payout.Payment_Transaction__c = paymentTxn.Id;
        update payout;
        Test.stopTest();

        payout = [
            SELECT Is_Paid__c, Payment_Transaction__c
            FROM Payout__c
            WHERE Id = :payout.Id
        ];
        System.assertEquals(true, payout.Is_Paid__c, 'Payout should be marked paid.');
        System.assertEquals(paymentTxn.Id, payout.Payment_Transaction__c, 'Payment transaction should be linked.');
    }

    @IsTest
    static void blocksInvalidPaymentTransaction() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = createIncomeTransaction(data.asset.Id);
        Payout__c payout = new Payout__c(
            Transaction__c = incomeTxn.Id,
            Owner__c = data.ownerOne.Id,
            Amount__c = 300,
            Ownership_Percentage__c = 60,
            Is_Paid__c = false
        );
        insert payout;

        Transaction__c invalidPaymentTxn = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Owner__c = data.ownerTwo.Id,
            Type__c = 'Other_Expense',
            Amount__c = 10,
            Transaction_Date__c = System.now()
        );
        insert invalidPaymentTxn;

        payout.Is_Paid__c = true;
        payout.Payment_Transaction__c = invalidPaymentTxn.Id;
        Database.SaveResult result = Database.update(payout, false);

        System.assertEquals(false, result.isSuccess(), 'Invalid payment transaction should be blocked.');
    }

    @IsTest
    static void blocksPaidPayoutFinancialChanges() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = createIncomeTransaction(data.asset.Id);
        Transaction__c paymentTxn = new Transaction__c(
            Shared_Asset__c = data.asset.Id,
            Owner__c = data.ownerOne.Id,
            Type__c = 'Profit_Distribution',
            Amount__c = 300,
            Transaction_Date__c = System.now()
        );
        insert paymentTxn;

        Payout__c payout = new Payout__c(
            Transaction__c = incomeTxn.Id,
            Owner__c = data.ownerOne.Id,
            Amount__c = 300,
            Ownership_Percentage__c = 60,
            Is_Paid__c = true,
            Payment_Transaction__c = paymentTxn.Id
        );
        insert payout;

        payout.Amount__c = 301;
        Database.SaveResult result = Database.update(payout, false);

        System.assertEquals(false, result.isSuccess(), 'Paid payout amount should be locked.');
    }

    @IsTest
    static void domainFactoryConstructsPayoutDomain() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = createIncomeTransaction(data.asset.Id);
        PayoutDomain.IPayouts domain = PayoutDomain.newInstance(
            new List<Payout__c>{
                new Payout__c(
                    Transaction__c = incomeTxn.Id,
                    Owner__c = data.ownerOne.Id,
                    Amount__c = 300,
                    Ownership_Percentage__c = 60,
                    Is_Paid__c = false
                )
            }
        );

        Test.startTest();
        domain.validatePayouts();
        Test.stopTest();

        System.assertNotEquals(null, domain, 'Domain factory should construct PayoutDomain.');
    }

    @IsTest
    static void domainFactoryConstructsPayoutDomainFromIds() {
        TestData data = createAssetWithOwners();
        Transaction__c incomeTxn = createIncomeTransaction(data.asset.Id);
        Payout__c payout = new Payout__c(
            Transaction__c = incomeTxn.Id,
            Owner__c = data.ownerOne.Id,
            Amount__c = 300,
            Ownership_Percentage__c = 60,
            Is_Paid__c = false
        );
        insert payout;

        PayoutDomain.IPayouts domain = PayoutDomain.newInstance(new Set<Id>{ payout.Id });

        System.assertNotEquals(null, domain, 'Domain factory should construct PayoutDomain from ids.');
    }

    private static Transaction__c createIncomeTransaction(Id assetId) {
        Transaction__c incomeTxn = new Transaction__c(
            Shared_Asset__c = assetId,
            Type__c = 'Other_Income',
            Amount__c = 1000,
            Transaction_Date__c = System.now()
        );
        insert incomeTxn;
        return incomeTxn;
    }

    private static TestData createAssetWithOwners() {
        TestData data = new TestData();
        data.asset = new Shared_Asset__c(
            Name = 'Shared Vehicle',
            Category__c = 'Car',
            Purchase_Date__c = Date.today(),
            Purchase_Price__c = 1000,
            Current_Value__c = 1000,
            Status__c = 'Active'
        );
        insert data.asset;

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

    private class TestData {
        Shared_Asset__c asset;
        Contact ownerOne;
        Contact ownerTwo;
    }
}
