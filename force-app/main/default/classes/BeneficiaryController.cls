/**
 * Thin @AuraEnabled facade for the beneficiaryManager LWC.
 * Business rules live in BeneficiaryService and AllocationValidator.
 */
public with sharing class BeneficiaryController {
  @AuraEnabled(cacheable=true)
  public static List<Beneficiary__c> getBeneficiaries(Id policyId) {
    try {
      return BeneficiaryService.getBeneficiaries(policyId);
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  @AuraEnabled
  public static List<Beneficiary__c> saveBeneficiaries(
    Id policyId,
    List<Beneficiary__c> rows
  ) {
    try {
      return BeneficiaryService.saveBeneficiaries(policyId, rows);
    } catch (Exception e) {
      throw toAuraException(e);
    }
  }

  private static AuraHandledException toAuraException(Exception e) {
    AuraHandledException ex = new AuraHandledException(e.getMessage());
    ex.setMessage(e.getMessage());
    return ex;
  }
}
