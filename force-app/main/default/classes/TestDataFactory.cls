@isTest
public class TestDataFactory {
  
  public static List<Product__c> createMockProducts(
    Integer recordCount,
    String category,
    Boolean doInsert
  ) {

    if(category == null){
      category = 'Hardware';
    }

    List<Product__c> products = new List<Product__c>();
    for (Integer i = 0; i < recordCount; i++) {
      products.add(
        new Product__c(
          Name = 'Test Product ' + String.valueOf(i).leftPad(4, '0'),
          Category__c = category,
          Unit_Price__c = 10 + i,
          Active__c = false
        )
      );
    }
    if (doInsert) {
      insert products;
    }
    return products;
  }
}