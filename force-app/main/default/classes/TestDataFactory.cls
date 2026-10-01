/**
 * Synthetic test data. No real names, policy numbers or customer data.
 */
@IsTest
public class TestDataFactory {
  public static Policy__c createPolicy(String policyNumber) {
    Policy__c policy = new Policy__c(
      Name = policyNumber,
      Product_Type__c = 'Term Life',
      Status__c = 'Active',
      Policyholder_Name__c = 'Test Policyholder'
    );
    insert policy;
    return policy;
  }

  public static Beneficiary__c newBeneficiary(
    String name,
    String designation,
    Decimal pct
  ) {
    return new Beneficiary__c(
      Full_Name__c = name,
      Relationship__c = 'Other',
      Designation__c = designation,
      Allocation_Percent__c = pct
    );
  }

  public static User createUser(String profileName, String permissionSetName) {
    Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
    String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    User u = new User(
      Alias = 'tuser',
      Email = 'test.user' + unique + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Tester',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = p.Id,
      TimeZoneSidKey = 'America/New_York',
      Username = 'test.user' + unique + '@example.com.portfolio'
    );
    // Setup objects are inserted inside runAs to avoid MIXED_DML_OPERATION
    // when the calling test also writes business records.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert u;
      if (permissionSetName != null) {
        PermissionSet ps = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = :permissionSetName
          LIMIT 1
        ];
        insert new PermissionSetAssignment(
          AssigneeId = u.Id,
          PermissionSetId = ps.Id
        );
      }
    }
    return u;
  }
}
