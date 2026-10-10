@isTest
private class ProductCatalogueControllerTest {
  @TestSetup
  static void setupTestData() {
    TestDataFactory.createMockProducts(3, null, true);
  }

  @isTest
  static void testGetProducts() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueController.getProducts(
      null,
      'Name',
      'ASC'
    );
    Test.stopTest();

    Assert.areEqual(
      3,
      results.size(),
      'All 3 seeded products should be returned'
    );
  }

  @isTest
  static void testSetProductActiveStatus() {
    Product__c product = [SELECT Id, Active__c FROM Product__c LIMIT 1];

    Test.startTest();
    ProductCatalogueController.setActiveStatus(product.Id, true);
    Test.stopTest();

    Product__c updated = [
      SELECT Active__c
      FROM Product__c
      WHERE Id = :product.Id
    ];
    Assert.isTrue(
      updated.Active__c,
      'Product should be active after setActiveStatus(true)'
    );
  }

  @isTest
  static void testSetProductStatusFailed() {
    Test.startTest();
    try {
      ProductCatalogueController.setActiveStatus(null, true);
      Assert.fail('Expected AuraHandledException for a null productId');
    } catch (AuraHandledException e) {
      Assert.isTrue(
        e.getMessage().contains('product and status are required'),
        'Exception message should explain the missing product/status input'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testSetProductActiveStatusToNull() {
    Product__c product = [SELECT Id FROM Product__c LIMIT 1];

    Test.startTest();
    try {
      ProductCatalogueController.setActiveStatus(product.Id, null);
      Assert.fail('Expected AuraHandledException for a null isActive value');
    } catch (AuraHandledException e) {
      Assert.isTrue(
        e.getMessage().contains('product and status are required'),
        'Exception message should explain the missing product/status input'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testGetRecentPriceChangesNoHistoryInTestContext() {
    Product__c product = [SELECT Id, Unit_Price__c FROM Product__c LIMIT 1];
    product.Unit_Price__c = 777;
    update product;

    Test.startTest();
    List<ProductCatalogueService.PriceHistory> history = ProductCatalogueController.getRecentPriceChanges(
      product.Id,
      5
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      history.size(),
      'Product__History rows are never created during Apex tests, so no price changes should be returned'
    );
  }

  @isTest
  static void testGetRecentPriceChangesProductIdIsNull() {
    Test.startTest();
    try {
      ProductCatalogueController.getRecentPriceChanges(null, 5);
      Assert.fail('Expected AuraHandledException for a null productId');
    } catch (AuraHandledException e) {
      Assert.isTrue(
        e.getMessage().contains('product is required'),
        'Exception message should explain the missing product input'
      );
    }
    Test.stopTest();
  }
}
