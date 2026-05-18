@IsTest
private class AssetOwnershipServiceTest {
    @IsTest
    static void allowsValidOwnershipSplit() {
        Shared_Asset__c asset = createAsset();
        Contact ownerOne = new Contact(LastName = 'Owner One');
        Contact ownerTwo = new Contact(LastName = 'Owner Two');
        insert new List<Contact>{ ownerOne, ownerTwo };

        Test.startTest();
        insert new List<Asset_Ownership__c>{
            new Asset_Ownership__c(
                Shared_Asset__c = asset.Id,
                Owner__c = ownerOne.Id,
                Ownership_Percentage__c = 60,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            ),
            new Asset_Ownership__c(
                Shared_Asset__c = asset.Id,
                Owner__c = ownerTwo.Id,
                Ownership_Percentage__c = 40,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            )
        };
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT()
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c = :asset.Id
        ]);
    }

    @IsTest
    static void blocksDuplicateActiveOwnerForSameAsset() {
        Shared_Asset__c asset = createAsset();
        Contact owner = new Contact(LastName = 'Duplicate Owner');
        insert owner;

        insert new Asset_Ownership__c(
            Shared_Asset__c = asset.Id,
            Owner__c = owner.Id,
            Ownership_Percentage__c = 60,
            Start_Date__c = Date.today(),
            Is_Active__c = true
        );

        Database.SaveResult result = Database.insert(
            new Asset_Ownership__c(
                Shared_Asset__c = asset.Id,
                Owner__c = owner.Id,
                Ownership_Percentage__c = 40,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            ),
            false
        );

        System.assertEquals(false, result.isSuccess(), 'Duplicate active owners should be blocked.');
    }

    @IsTest
    static void blocksActiveOwnershipTotalAboveOneHundred() {
        Shared_Asset__c asset = createAsset();
        Contact ownerOne = new Contact(LastName = 'Owner One');
        Contact ownerTwo = new Contact(LastName = 'Owner Two');
        insert new List<Contact>{ ownerOne, ownerTwo };

        Database.SaveResult[] results = Database.insert(
            new List<Asset_Ownership__c>{
                new Asset_Ownership__c(
                    Shared_Asset__c = asset.Id,
                    Owner__c = ownerOne.Id,
                    Ownership_Percentage__c = 70,
                    Start_Date__c = Date.today(),
                    Is_Active__c = true
                ),
                new Asset_Ownership__c(
                    Shared_Asset__c = asset.Id,
                    Owner__c = ownerTwo.Id,
                    Ownership_Percentage__c = 40,
                    Start_Date__c = Date.today(),
                    Is_Active__c = true
                )
            },
            false
        );

        System.assertEquals(false, results[0].isSuccess(), 'Ownership totals above 100% should fail.');
        System.assertEquals(false, results[1].isSuccess(), 'Ownership totals above 100% should fail for every impacted row.');
    }

    @IsTest
    static void blocksUpdateThatPushesActiveOwnershipTotalAboveOneHundred() {
        Shared_Asset__c asset = createAsset();
        Contact ownerOne = new Contact(LastName = 'Owner One');
        Contact ownerTwo = new Contact(LastName = 'Owner Two');
        insert new List<Contact>{ ownerOne, ownerTwo };

        List<Asset_Ownership__c> ownerships = new List<Asset_Ownership__c>{
            new Asset_Ownership__c(
                Shared_Asset__c = asset.Id,
                Owner__c = ownerOne.Id,
                Ownership_Percentage__c = 60,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            ),
            new Asset_Ownership__c(
                Shared_Asset__c = asset.Id,
                Owner__c = ownerTwo.Id,
                Ownership_Percentage__c = 40,
                Start_Date__c = Date.today(),
                Is_Active__c = true
            )
        };
        insert ownerships;

        ownerships[1].Ownership_Percentage__c = 50;
        Database.SaveResult result = Database.update(ownerships[1], false);

        System.assertEquals(false, result.isSuccess(), 'Updates that push active ownership above 100% should fail.');
    }

    @IsTest
    static void domainFactoryConstructsAssetOwnershipDomain() {
        Shared_Asset__c asset = createAsset();
        Contact owner = new Contact(LastName = 'Factory Owner');
        insert owner;

        AssetOwnershipDomain.IAssetOwnerships domain = AssetOwnershipDomain.newInstance(
            new List<Asset_Ownership__c>{
                new Asset_Ownership__c(
                    Shared_Asset__c = asset.Id,
                    Owner__c = owner.Id,
                    Ownership_Percentage__c = 100,
                    Start_Date__c = Date.today(),
                    Is_Active__c = true
                )
            }
        );

        Test.startTest();
        domain.validateOwnerships();
        Test.stopTest();

        System.assertNotEquals(null, domain, 'Domain factory should construct the asset ownership domain.');
    }

    @IsTest
    static void domainFactoryConstructsAssetOwnershipDomainFromIds() {
        Shared_Asset__c asset = createAsset();
        Contact owner = new Contact(LastName = 'Factory Owner');
        insert owner;

        Asset_Ownership__c ownership = new Asset_Ownership__c(
            Shared_Asset__c = asset.Id,
            Owner__c = owner.Id,
            Ownership_Percentage__c = 100,
            Start_Date__c = Date.today(),
            Is_Active__c = true
        );
        insert ownership;

        AssetOwnershipDomain.IAssetOwnerships domain = AssetOwnershipDomain.newInstance(
            new Set<Id>{ ownership.Id }
        );

        System.assertNotEquals(null, domain, 'Domain factory should construct the domain from ids.');
    }

    @IsTest
    static void validatesRequiredFieldsAndDateRange() {
        Shared_Asset__c asset = createAsset();

        Database.SaveResult result = Database.insert(
            new Asset_Ownership__c(
                Shared_Asset__c = asset.Id,
                Ownership_Percentage__c = 0,
                Start_Date__c = Date.today(),
                End_Date__c = Date.today().addDays(-1),
                Is_Active__c = true
            ),
            false
        );

        System.assertEquals(false, result.isSuccess(), 'Invalid active ownership should be blocked.');
    }

    @IsTest
    static void allowsInactiveHistoricalRecordForSameOwner() {
        Shared_Asset__c asset = createAsset();
        Contact owner = new Contact(LastName = 'Historical Owner');
        insert owner;

        insert new Asset_Ownership__c(
            Shared_Asset__c = asset.Id,
            Owner__c = owner.Id,
            Ownership_Percentage__c = 100,
            Start_Date__c = Date.today(),
            Is_Active__c = true
        );

        Test.startTest();
        insert new Asset_Ownership__c(
            Shared_Asset__c = asset.Id,
            Owner__c = owner.Id,
            Ownership_Percentage__c = 50,
            Start_Date__c = Date.today().addYears(-1),
            End_Date__c = Date.today().addDays(-1),
            Is_Active__c = false
        );
        Test.stopTest();

        System.assertEquals(2, [
            SELECT COUNT()
            FROM Asset_Ownership__c
            WHERE Shared_Asset__c = :asset.Id
        ]);
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
