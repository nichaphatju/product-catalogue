public with sharing class ProductCatalogueController {
  /**
   * @param categoryFilter Category__c value to filter by, or null/blank for all categories
   * @param sortField 'Name' or 'Unit_Price__c'
   * @param sortDirection 'ASC' or 'DESC'
   * @return Matching products for display in the catalogue
   * @throws AuraHandledException when the products cannot be retrieved
   */
  @AuraEnabled
  public static List<Product__c> getProducts(
    String categoryFilter,
    String sortField,
    String sortDirection
  ) {
    try {
      return ProductCatalogueService.listProducts(
        categoryFilter,
        sortField,
        sortDirection
      );
    } catch (Exception e) {
      AuraHandledException ae = new AuraHandledException('Get Products Failed');
      ae.setMessage('We couldn\'t load the product catalogue. Please try again later: ' + e.getMessage());
      throw ae;
    }
  }

  /**
   * @param productId Id of the Product__c record to update
   * @param isActive New Active__c value
   * @throws AuraHandledException when productId is missing or the update fails
   */
  @AuraEnabled
  public static void setActiveStatus(Id productId, Boolean isActive) {
    if (productId == null || isActive == null) {
      AuraHandledException e = new AuraHandledException('Set Product Status Failed');
      e.setMessage('A product and status are required to update active status.');
      throw e;
    }
    try {
      ProductCatalogueService.updateProductStatus(productId, isActive);
    } catch (Exception e) {
      AuraHandledException ae = new AuraHandledException('Set Product Status Failed');
      ae.setMessage(e.getMessage());
      throw ae;
    }
  }

  /**
   * @param productId Id of the Product__c record
   * @param maxRecords Maximum number of changes to return; defaults to 5 when null
   * @return Recent Unit Price changes, most recent first
   * @throws AuraHandledException when productId is missing or history cannot be retrieved
   */
  @AuraEnabled(cacheable=true)
  public static List<ProductCatalogueService.PriceHistory> getRecentPriceChanges(
    Id productId,
    Integer maxRecords
  ) {
    if (productId == null) {
      AuraHandledException e = new AuraHandledException('Get Price Changes Failed');
      e.setMessage('A product is required to view price history.');
      throw e;
    }
    try {
      return ProductCatalogueService.getPriceHistory(productId, maxRecords);
    } catch (Exception e) {
      AuraHandledException ae = new AuraHandledException('Get Price Changes Failed');
      ae.setMessage('We couldn\'t load the price history for this product: ' + e.getMessage());
      throw ae;
    }
  }
}