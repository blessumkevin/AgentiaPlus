/**
 * @description Test class for AccountRatingCalculator
 * @author ACME Corporation
 * @date 2026-03-19
 */
@isTest
private class AccountRatingCalculatorTest {

    @testSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>();

        // Hot Account: revenue 3pts + employees 3pts + 12 opps 3pts = 9 pts
        accounts.add(new Account(Name = 'Hot Test Account',  AnnualRevenue = 15000000, NumberOfEmployees = 1500));
        // Warm Account: revenue 2pts + employees 2pts + 6 opps 2pts = 6 pts
        accounts.add(new Account(Name = 'Warm Test Account', AnnualRevenue = 6000000,  NumberOfEmployees = 600));
        // Cold Account: revenue 0pts + employees 0pts + 1 opp 1pt = 1 pt
        accounts.add(new Account(Name = 'Cold Test Account', AnnualRevenue = 500000,   NumberOfEmployees = 50));
        // Zero values
        accounts.add(new Account(Name = 'Zero Test Account', AnnualRevenue = 0,        NumberOfEmployees = 0));
        // Null values
        accounts.add(new Account(Name = 'Null Test Account'));

        insert accounts;

        Account hotAcc  = [SELECT Id FROM Account WHERE Name = 'Hot Test Account'  LIMIT 1];
        Account warmAcc = [SELECT Id FROM Account WHERE Name = 'Warm Test Account' LIMIT 1];
        Account coldAcc = [SELECT Id FROM Account WHERE Name = 'Cold Test Account' LIMIT 1];

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 12; i++) {
            opps.add(new Opportunity(Name = 'Hot Opp '  + i, AccountId = hotAcc.Id,  StageName = 'Prospecting', CloseDate = Date.today().addDays(30)));
        }
        for (Integer i = 0; i < 6; i++) {
            opps.add(new Opportunity(Name = 'Warm Opp ' + i, AccountId = warmAcc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30)));
        }
        opps.add(new Opportunity(Name = 'Cold Opp', AccountId = coldAcc.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30)));
        insert opps;
    }

    @isTest
    static void testHotRatingCalculation() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Hot Test Account' LIMIT 1];
        Test.startTest();
        String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
        Test.stopTest();
        System.assertEquals('Hot', rating, 'Account should be rated Hot');
    }

    @isTest
    static void testWarmRatingCalculation() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Warm Test Account' LIMIT 1];
        Test.startTest();
        String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
        Test.stopTest();
        System.assertEquals('Warm', rating, 'Account should be rated Warm');
    }

    @isTest
    static void testColdRatingCalculation() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Cold Test Account' LIMIT 1];
        Test.startTest();
        String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
        Test.stopTest();
        System.assertEquals('Cold', rating, 'Account should be rated Cold');
    }

    @isTest
    static void testZeroValuesAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Zero Test Account' LIMIT 1];
        Test.startTest();
        String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
        Test.stopTest();
        System.assertEquals('Cold', rating, 'Zero-value account should be rated Cold');
    }

    @isTest
    static void testNullValuesAccount() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Null Test Account' LIMIT 1];
        Test.startTest();
        String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
        Test.stopTest();
        System.assertEquals('Cold', rating, 'Null-value account should be rated Cold');
    }

    @isTest
    static void testBulkRatingCalculation() {
        List<Account> accounts = [SELECT Id FROM Account];
        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
        Test.startTest();
        Map<Id, String> ratings = AccountRatingCalculator.calculateAccountRatings(accountIds);
        Test.stopTest();
        System.assertEquals(5, ratings.size(), 'Should calculate ratings for all 5 accounts');
        System.assert(ratings.values().contains('Hot'),  'Should contain a Hot rating');
        System.assert(ratings.values().contains('Warm'), 'Should contain a Warm rating');
        System.assert(ratings.values().contains('Cold'), 'Should contain a Cold rating');
    }

    @isTest
    static void testUpdateAccountRatings() {
        List<Account> accounts = [SELECT Id FROM Account];
        Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
        Test.startTest();
        AccountRatingCalculator.updateAccountRatings(accountIds);
        Test.stopTest();
        for (Account acc : [SELECT Id, Name, Rating FROM Account]) {
            System.assertNotEquals(null, acc.Rating, 'Rating should be set for: ' + acc.Name);
        }
    }

    @isTest
    static void testNullAccountIdException() {
        Test.startTest();
        try {
            AccountRatingCalculator.calculateAccountRating(null);
            System.assert(false, 'Should have thrown AccountRatingException');
        } catch (AccountRatingCalculator.AccountRatingException e) {
            System.assert(e.getMessage().containsIgnoreCase('null'), 'Exception should mention null');
        }
        Test.stopTest();
    }

    @isTest
    static void testInvalidAccountIdException() {
        String keyPrefix = Account.SObjectType.getDescribe().getKeyPrefix();
        Id fakeId = Id.valueOf(keyPrefix + '0'.repeat(15 - keyPrefix.length()));
        Test.startTest();
        try {
            AccountRatingCalculator.calculateAccountRating(fakeId);
            System.assert(false, 'Should have thrown AccountRatingException');
        } catch (AccountRatingCalculator.AccountRatingException e) {
            System.assert(e.getMessage().containsIgnoreCase('not found'), 'Exception should mention not found');
        }
        Test.stopTest();
    }

    @isTest
    static void testEmptySetHandling() {
        Test.startTest();
        Map<Id, String> ratings = AccountRatingCalculator.calculateAccountRatings(new Set<Id>());
        Test.stopTest();
        System.assertEquals(0, ratings.size(), 'Empty set should return empty map');
    }

    @isTest
    static void testNullSetHandling() {
        Test.startTest();
        Map<Id, String> ratings = AccountRatingCalculator.calculateAccountRatings(null);
        Test.stopTest();
        System.assertEquals(0, ratings.size(), 'Null set should return empty map');
    }

    @isTest
    static void testRevenueScoringTiers() {
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Rev Tier 3', AnnualRevenue = 10000000, NumberOfEmployees = 0),
            new Account(Name = 'Rev Tier 2', AnnualRevenue = 5000000,  NumberOfEmployees = 0),
            new Account(Name = 'Rev Tier 1', AnnualRevenue = 1000000,  NumberOfEmployees = 0)
        };
        insert testAccounts;
        Test.startTest();
        for (Account acc : testAccounts) {
            String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
            System.assertNotEquals(null, rating, 'Rating should be set for ' + acc.Name);
        }
        Test.stopTest();
    }

    @isTest
    static void testEmployeeScoringTiers() {
        List<Account> testAccounts = new List<Account>{
            new Account(Name = 'Emp Tier 3', NumberOfEmployees = 1000, AnnualRevenue = 0),
            new Account(Name = 'Emp Tier 2', NumberOfEmployees = 500,  AnnualRevenue = 0),
            new Account(Name = 'Emp Tier 1', NumberOfEmployees = 100,  AnnualRevenue = 0)
        };
        insert testAccounts;
        Test.startTest();
        for (Account acc : testAccounts) {
            String rating = AccountRatingCalculator.calculateAccountRating(acc.Id);
            System.assertNotEquals(null, rating, 'Rating should be set for ' + acc.Name);
        }
        Test.stopTest();
    }

    @isTest
    static void testOpportunityScoringTiers() {
        Account testAccount = new Account(Name = 'Opp Tier Test', AnnualRevenue = 0, NumberOfEmployees = 0);
        insert testAccount;
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 10; i++) {
            opps.add(new Opportunity(Name = 'Test Opp ' + i, AccountId = testAccount.Id, StageName = 'Prospecting', CloseDate = Date.today().addDays(30)));
        }
        insert opps;
        Test.startTest();
        String rating = AccountRatingCalculator.calculateAccountRating(testAccount.Id);
        Test.stopTest();
        System.assertNotEquals(null, rating, 'Rating should be calculated');
    }

    @isTest
    static void testFlowInvocable() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Hot Test Account' LIMIT 1];
        AccountRatingCalculator.FlowRequest req = new AccountRatingCalculator.FlowRequest();
        req.accountId = acc.Id;
        Test.startTest();
        AccountRatingCalculator.updateAccountRatingFromFlow(new List<AccountRatingCalculator.FlowRequest>{ req });
        Test.stopTest();
        Account updated = [SELECT Rating FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, updated.Rating, 'Rating should be set after flow invocation');
    }

    @isTest
    static void testFlowInvocableNullRequest() {
        Test.startTest();
        AccountRatingCalculator.updateAccountRatingFromFlow(null);
        AccountRatingCalculator.updateAccountRatingFromFlow(new List<AccountRatingCalculator.FlowRequest>());
        Test.stopTest();
        // No exception means success
        System.assert(true, 'Null/empty flow requests should be handled gracefully');
    }
}