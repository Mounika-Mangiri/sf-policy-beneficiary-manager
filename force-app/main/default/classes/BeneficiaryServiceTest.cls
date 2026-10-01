@IsTest
private class BeneficiaryServiceTest {
  @TestSetup
  static void setup() {
    Policy__c policy = TestDataFactory.createPolicy('TEST-POL-0001');
    insert new List<Beneficiary__c>{
      new Beneficiary__c(
        Policy__c = policy.Id,
        Full_Name__c = 'Alex Example',
        Relationship__c = 'Spouse',
        Designation__c = 'Primary',
        Allocation_Percent__c = 100
      ),
      new Beneficiary__c(
        Policy__c = policy.Id,
        Full_Name__c = 'Sam Example',
        Relationship__c = 'Child',
        Designation__c = 'Contingent',
        Allocation_Percent__c = 100
      )
    };
  }

  private static Policy__c policy() {
    return [SELECT Id FROM Policy__c WHERE Name = 'TEST-POL-0001' LIMIT 1];
  }

  @IsTest
  static void getReturnsPrimaryFirst() {
    List<Beneficiary__c> rows = BeneficiaryService.getBeneficiaries(
      policy().Id
    );
    Assert.areEqual(2, rows.size());
    Assert.areEqual('Primary', rows[0].Designation__c);
  }

  @IsTest
  static void saveInsertsUpdatesAndDeletes() {
    Id policyId = policy().Id;
    List<Beneficiary__c> current = BeneficiaryService.getBeneficiaries(
      policyId
    );
    Beneficiary__c primary = current[0];
    primary.Allocation_Percent__c = 70;

    // Keep the primary (updated), drop the contingent, add a new primary.
    List<Beneficiary__c> payload = new List<Beneficiary__c>{
      primary,
      TestDataFactory.newBeneficiary('Jordan Example', 'Primary', 30)
    };

    Test.startTest();
    List<Beneficiary__c> saved = BeneficiaryService.saveBeneficiaries(
      policyId,
      payload
    );
    Test.stopTest();

    Assert.areEqual(2, saved.size());
    Decimal total = 0;
    for (Beneficiary__c b : saved) {
      Assert.areEqual('Primary', b.Designation__c);
      total += b.Allocation_Percent__c;
    }
    Assert.areEqual(100, total);
  }

  @IsTest
  static void invalidAllocationChangesNothing() {
    Id policyId = policy().Id;
    try {
      BeneficiaryService.saveBeneficiaries(
        policyId,
        new List<Beneficiary__c>{
          TestDataFactory.newBeneficiary('Jordan Example', 'Primary', 50)
        }
      );
      Assert.fail('Expected a BeneficiaryException');
    } catch (BeneficiaryService.BeneficiaryException e) {
      Assert.isTrue(e.getMessage().contains('must total 100'));
    }
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Beneficiary__c WHERE Policy__c = :policyId]
    );
  }

  @IsTest
  static void foreignBeneficiaryIdIsRejected() {
    Policy__c other = TestDataFactory.createPolicy('TEST-POL-0002');
    Beneficiary__c foreign = new Beneficiary__c(
      Policy__c = other.Id,
      Full_Name__c = 'Other Example',
      Relationship__c = 'Other',
      Designation__c = 'Primary',
      Allocation_Percent__c = 100
    );
    insert foreign;

    try {
      BeneficiaryService.saveBeneficiaries(
        policy().Id,
        new List<Beneficiary__c>{ foreign }
      );
      Assert.fail('Expected a BeneficiaryException');
    } catch (BeneficiaryService.BeneficiaryException e) {
      Assert.isTrue(e.getMessage().contains('does not belong'));
    }
  }

  @IsTest
  static void nullPolicyIdIsRejected() {
    try {
      BeneficiaryService.getBeneficiaries(null);
      Assert.fail('Expected a BeneficiaryException');
    } catch (BeneficiaryService.BeneficiaryException e) {
      Assert.isTrue(e.getMessage().contains('required'));
    }
  }

  @IsTest
  static void userWithoutPermissionCannotRead() {
    User noAccess = TestDataFactory.createUser(
      'Minimum Access - Salesforce',
      null
    );
    Id policyId = policy().Id;
    System.runAs(noAccess) {
      try {
        BeneficiaryService.getBeneficiaries(policyId);
        Assert.fail('Expected user-mode query to fail without object access');
      } catch (Exception e) {
        // User mode rejects the query because the profile has no object access.
        Assert.isNotNull(e.getMessage());
      }
    }
  }

  @IsTest
  static void userWithPermissionSetCanSave() {
    User agent = TestDataFactory.createUser(
      'Standard User',
      'Beneficiary_Manager'
    );
    Policy__c policyRecord = policy();
    // The test user needs sharing access to the policy.
    policyRecord.OwnerId = agent.Id;
    update policyRecord;

    System.runAs(agent) {
      List<Beneficiary__c> saved = BeneficiaryService.saveBeneficiaries(
        policyRecord.Id,
        new List<Beneficiary__c>{
          TestDataFactory.newBeneficiary('Riley Example', 'Primary', 100)
        }
      );
      Assert.areEqual(1, saved.size());
    }
  }
}
