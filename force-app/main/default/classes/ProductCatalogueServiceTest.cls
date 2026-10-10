@isTest
private class ProductCatalogueServiceTest {
  @TestSetup
  static void setupTestData() {
    TestDataFactory.createMockProducts(5, null, true);
  }

  @isTest
  static void testListProductsNoFilter() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Name',
      'ASC'
    );
    Test.stopTest();

    Assert.areEqual(
      5,
      results.size(),
      'All 5 seeded products should be returned when no filter is applied'
    );
  }

  @isTest
  static void testListProductsByCategory() {
    Product__c softwareProduct = new Product__c(
      Name = 'Software Product',
      Category__c = 'Software',
      Unit_Price__c = 50
    );
    insert softwareProduct;

    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      'Software',
      'Name',
      'ASC'
    );
    Test.stopTest();

    Assert.areEqual(
      1,
      results.size(),
      'Only the Software category product should be returned'
    );
    Assert.areEqual(
      softwareProduct.Id,
      results[0].Id,
      'The returned product should be the Software one just inserted'
    );
  }

  @isTest
  static void testListProductsSortByNameAscending() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Name',
      'ASC'
    );
    Test.stopTest();

    Assert.areEqual(
      'Test Product 0000',
      results[0].Name,
      'First record should be the lowest-named product'
    );
    Assert.areEqual(
      'Test Product 0004',
      results[4].Name,
      'Last record should be the highest-named product'
    );
  }

  @isTest
  static void testListProductsSortByNameDescending() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Name',
      'DESC'
    );
    Test.stopTest();

    Assert.areEqual(
      'Test Product 0004',
      results[0].Name,
      'First record should be the highest-named product'
    );
    Assert.areEqual(
      'Test Product 0000',
      results[4].Name,
      'Last record should be the lowest-named product'
    );
  }

  @isTest
  static void testListProductsSortByUnitPriceAscending() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Unit_Price__c',
      'ASC'
    );
    Test.stopTest();

    Assert.areEqual(
      10,
      results[0].Unit_Price__c,
      'First record should have the lowest unit price'
    );
    Assert.areEqual(
      14,
      results[4].Unit_Price__c,
      'Last record should have the highest unit price'
    );
  }

  @isTest
  static void testListProductsSortByUnitPriceDescending() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Unit_Price__c',
      'DESC'
    );
    Test.stopTest();

    Assert.areEqual(
      14,
      results[0].Unit_Price__c,
      'First record should have the highest unit price'
    );
    Assert.areEqual(
      10,
      results[4].Unit_Price__c,
      'Last record should have the lowest unit price'
    );
  }

  @isTest
  static void testListProductsInvalidSortField() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'DROP TABLE Product__c',
      'ASC'
    );
    Test.stopTest();

    Assert.areEqual(
      'Test Product 0000',
      results[0].Name,
      'An invalid sort field should fall back to sorting by Name'
    );
  }

  @isTest
  static void testListProductsInvalidSortDirection() {
    Test.startTest();
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Name',
      'garbage'
    );
    Test.stopTest();

    Assert.areEqual(
      'Test Product 0000',
      results[0].Name,
      'An invalid sort direction should fall back to ASC'
    );
  }

  @isTest
  static void testUpdateProductStatusToTrue() {
    Product__c product = [SELECT Id, Active__c FROM Product__c LIMIT 1];

    Test.startTest();
    ProductCatalogueService.updateProductStatus(product.Id, true);
    Test.stopTest();

    Product__c updated = [
      SELECT Active__c
      FROM Product__c
      WHERE Id = :product.Id
    ];
    Assert.isTrue(
      updated.Active__c,
      'Product should be active after updateProductStatus(true)'
    );
  }

  @isTest
  static void testUpdateProductStatusToFalse() {
    Product__c product = [SELECT Id, Active__c FROM Product__c LIMIT 1];
    ProductCatalogueService.updateProductStatus(product.Id, true);

    Test.startTest();
    ProductCatalogueService.updateProductStatus(product.Id, false);
    Test.stopTest();

    Product__c updated = [
      SELECT Active__c
      FROM Product__c
      WHERE Id = :product.Id
    ];
    Assert.isFalse(
      updated.Active__c,
      'Product should be inactive after updateProductStatus(false)'
    );
  }

  @isTest
  static void testUpdateProductStatusNonExistent() {
    Product__c product = [SELECT Id FROM Product__c LIMIT 1];
    delete product;

    Test.startTest();
    try {
      ProductCatalogueService.updateProductStatus(product.Id, true);
      Assert.fail(
        'Expected ProductCatalogueServiceException for a non-existent product Id'
      );
    } catch (ProductCatalogueService.ProductCatalogueServiceException e) {
      Assert.isTrue(
        e.getMessage().contains('Unable to update product status'),
        'Exception message should explain the update failure'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testGetPriceHistoryNoHistoryInTestContext() {
    Product__c product = [SELECT Id, Unit_Price__c FROM Product__c LIMIT 1];

    Test.startTest();
    product.Unit_Price__c = 999;
    update product;
    List<ProductCatalogueService.PriceHistory> history = ProductCatalogueService.getPriceHistory(
      product.Id,
      5
    );
    Test.stopTest();

    // Field History Tracking rows (Product__History) are written by an asynchronous
    // platform process and are never created during Apex test execution, regardless of
    // the Unit_Price__c update above. getPriceHistory() can therefore only be verified
    // here as returning a clean, empty list rather than specific history content -
    // there is no supported way to insert or simulate Product__History rows in a test.
    Assert.areEqual(
      0,
      history.size(),
      'Product__History rows are never created during Apex tests, so no price changes should be returned'
    );
  }

  @isTest
  static void testGetPriceHistoryNoHistoryInTestContextWithDefaultLimit() {
    Product__c product = [SELECT Id, Unit_Price__c FROM Product__c LIMIT 1];
    product.Unit_Price__c = 500;
    update product;

    Test.startTest();
    List<ProductCatalogueService.PriceHistory> history = ProductCatalogueService.getPriceHistory(
      product.Id,
      null
    );
    Test.stopTest();

    Assert.areEqual(
      0,
      history.size(),
      'Product__History rows are never created during Apex tests, even with the default maxRecords'
    );
  }

  @isTest
  static void testListProductsBulkInsertAndSort() {
    List<Product__c> bulkProducts = TestDataFactory.createMockProducts(
      200,
      'Software',
      false
    );

    Test.startTest();
    insert bulkProducts;
    List<Product__c> results = ProductCatalogueService.listProducts(
      null,
      'Unit_Price__c',
      'ASC'
    );
    Test.stopTest();

    // 5 from @TestSetup + 200 bulk-inserted here
    Assert.areEqual(
      205,
      results.size(),
      'listProducts should return every seeded and bulk-inserted product'
    );
  }

  @isTest
  static void testInsertInvalidProduct() {
    Product__c invalidProduct = new Product__c(
      Name = 'Invalid Price Product',
      Category__c = 'Hardware',
      Unit_Price__c = 0
    );

    Test.startTest();
    try {
      insert invalidProduct;
      Assert.fail(
        'Expected a DmlException from the Prevent_Invalid_Unit_Price validation rule'
      );
    } catch (DmlException e) {
      Assert.isTrue(
        e.getMessage().contains('Unit Price must be greater than 0'),
        'Validation rule error message should explain the Unit Price constraint'
      );
    }
    Test.stopTest();
  }
}
