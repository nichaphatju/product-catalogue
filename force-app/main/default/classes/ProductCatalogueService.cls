public with sharing class ProductCatalogueService {
  private static final Set<String> ALLOWED_SORT_FIELDS = new Set<String>{
    'Name',
    'Unit_Price__c'
  };
  private static final Set<String> ALLOWED_SORT_DIRECTIONS = new Set<String>{'ASC', 'DESC'};
  private static final String DEFAULT_SORT_FIELD = 'Name';
  private static final String DEFAULT_SORT_DIRECTION = 'ASC';
  private static final Integer DEFAULT_PRICE_HISTORY_LIMIT = 5;
  private static final String UNIT_PRICE_FIELD_API_NAME = 'Unit_Price__c';

  /**
   * Lists products, optionally filtered by category, sorted by an allowlisted field/direction.
   * @param categoryFilter Category__c value to filter by, or null/blank for all categories
   * @param sortField 'Name' or 'Unit_Price__c'; defaults to 'Name' when blank or not allowlisted
   * @param sortDirection 'ASC' or 'DESC'; defaults to 'ASC' when blank or not allowlisted
   * @return Matching Product__c records with Name, Category__c, Unit_Price__c, Active__c
   */
  public static List<Product__c> listProducts(
    String categoryFilter,
    String sortField,
    String sortDirection
  ) {
    String safeSortField = ALLOWED_SORT_FIELDS.contains(sortField) ? sortField : DEFAULT_SORT_FIELD;
    String safeSortDirection = ALLOWED_SORT_DIRECTIONS.contains(sortDirection) ? sortDirection : DEFAULT_SORT_DIRECTION;

    String query = 'SELECT Id, Name, Category__c, Unit_Price__c, Active__c FROM Product__c ';
      query += (String.isNotBlank(categoryFilter)
        ? 'WHERE Category__c = :categoryFilter '
        : '') +
      'ORDER BY ' +
      safeSortField +
      ' ' +
      safeSortDirection;

    return Database.query(query);
  }

  /**
   * Updates the Active__c status of a single product. Uses bulk-safe, partial-success
   * DML even for a single record so failures surface as clear, specific errors.
   * @param productId Id of the Product__c record to update
   * @param isActive New Active__c value
   * @throws ProductCatalogueServiceException if the update fails
   */
  public static void updateProductStatus(Id productId, Boolean isActive) {
    Product__c productToUpdate = new Product__c(
      Id = productId,
      Active__c = isActive
    );
    List<Product__c> recordsToUpdate = new List<Product__c>{ productToUpdate };

    List<Database.SaveResult> saveResults = Database.update(recordsToUpdate, false, AccessLevel.USER_MODE);

    List<String> errorMessages = new List<String>();
    for (Database.SaveResult saveResult : saveResults) {
      if (!saveResult.isSuccess()) {
        for (Database.Error dmlError : saveResult.getErrors()) {
          errorMessages.add(dmlError.getMessage());
        }
      }
    }
    if(!errorMessages.isEmpty()){
      throw new ProductCatalogueServiceException(
        'Unable to update product status: ' + String.join(errorMessages, '; ')
      );
    }
  }

  /**
   * Retrieves the most recent Unit Price changes for a product from field history.
   * @param productId Id of the Product__c record
   * @param maxRecords Maximum number of changes to return; defaults to 5 when null
   * @return Recent price changes, most recent first
   */
  public static List<PriceHistory> getPriceHistory(
    Id productId,
    Integer maxRecords
  ) {
    Integer resultLimit = (maxRecords == null || maxRecords <= 0) ? DEFAULT_PRICE_HISTORY_LIMIT : maxRecords;

    List<Product__History> historyRecords = [
      SELECT NewValue, OldValue, CreatedDate
      FROM Product__History
      WHERE ParentId = :productId AND Field = :UNIT_PRICE_FIELD_API_NAME
      ORDER BY CreatedDate DESC
      LIMIT :resultLimit
    ];

    List<PriceHistory> priceChanges = new List<PriceHistory>();
    for (Product__History historyRecord : historyRecords) {
      priceChanges.add(
        new PriceHistory(
          historyRecord.CreatedDate,
          (String) historyRecord.OldValue,
          (String) historyRecord.NewValue
        )
      );
    }
    return priceChanges;
  }

  public class PriceHistory {
    @AuraEnabled
    public DateTime changedDate;
    @AuraEnabled
    public String oldValue;
    @AuraEnabled
    public String newValue;

    public PriceHistory(
      DateTime changedDate,
      String oldValue,
      String newValue
    ) {
      this.changedDate = changedDate;
      this.oldValue = oldValue;
      this.newValue = newValue;
    }
  }

  public class ProductCatalogueServiceException extends Exception {
  }
}