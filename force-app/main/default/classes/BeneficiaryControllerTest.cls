@IsTest
private class BeneficiaryControllerTest {
  @IsTest
  static void roundTrip() {
    Policy__c policy = TestDataFactory.createPolicy('TEST-POL-0100');
    List<Beneficiary__c> saved = BeneficiaryController.saveBeneficiaries(
      policy.Id,
      new List<Beneficiary__c>{
        TestDataFactory.newBeneficiary('Casey Example', 'Primary', 100)
      }
    );
    Assert.areEqual(1, saved.size());
    Assert.areEqual(
      1,
      BeneficiaryController.getBeneficiaries(policy.Id).size()
    );
  }

  @IsTest
  static void errorsSurfaceAsAuraHandledException() {
    Policy__c policy = TestDataFactory.createPolicy('TEST-POL-0101');
    try {
      BeneficiaryController.saveBeneficiaries(
        policy.Id,
        new List<Beneficiary__c>{
          TestDataFactory.newBeneficiary('Casey Example', 'Primary', 10)
        }
      );
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('must total 100'));
    }
  }

  @IsTest
  static void getErrorsSurfaceAsAuraHandledException() {
    try {
      BeneficiaryController.getBeneficiaries(null);
      Assert.fail('Expected AuraHandledException');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('required'));
    }
  }
}
