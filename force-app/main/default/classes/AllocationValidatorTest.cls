@IsTest
private class AllocationValidatorTest {
  private static Beneficiary__c ben(String designation, Decimal pct) {
    return TestDataFactory.newBeneficiary('Test Name', designation, pct);
  }

  @IsTest
  static void validPrimaryOnly() {
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>{ ben('Primary', 60), ben('Primary', 40) }
    );
    Assert.areEqual(0, errors.size(), String.join(errors, ' | '));
  }

  @IsTest
  static void validPrimaryAndContingent() {
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>{
        ben('Primary', 100),
        ben('Contingent', 33.33),
        ben('Contingent', 33.33),
        ben('Contingent', 33.34)
      }
    );
    Assert.areEqual(0, errors.size(), String.join(errors, ' | '));
  }

  @IsTest
  static void emptyListIsRejected() {
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>()
    );
    Assert.areEqual(1, errors.size());
    Assert.isTrue(errors[0].contains('primary'));
  }

  @IsTest
  static void primaryNotHundredIsRejected() {
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>{ ben('Primary', 50), ben('Primary', 40) }
    );
    Assert.areEqual(1, errors.size());
    Assert.isTrue(errors[0].contains('Primary allocations total 90'));
  }

  @IsTest
  static void contingentNotHundredIsRejected() {
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>{ ben('Primary', 100), ben('Contingent', 50) }
    );
    Assert.areEqual(1, errors.size());
    Assert.isTrue(errors[0].contains('Contingent'));
  }

  @IsTest
  static void onlyContingentIsRejected() {
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>{ ben('Contingent', 100) }
    );
    Assert.areEqual(1, errors.size());
    Assert.isTrue(errors[0].contains('primary'));
  }

  @IsTest
  static void outOfRangeAndBlankNameAreRejected() {
    Beneficiary__c blank = ben('Primary', 100);
    blank.Full_Name__c = '  ';
    List<String> errors = AllocationValidator.validate(
      new List<Beneficiary__c>{ blank, ben('Primary', 0), ben('Primary', null) }
    );
    Assert.isTrue(errors.size() >= 3, String.join(errors, ' | '));
    Assert.isTrue(errors[0].contains('Row 1: name is required'));
  }
}
