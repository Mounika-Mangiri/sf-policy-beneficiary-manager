/**
 * Reads and replaces the beneficiary designations on a policy.
 *
 * All queries and DML run in user mode, so object permissions, field-level
 * security and sharing of the running user are enforced (no silent escalation).
 * The save is all-or-nothing: a savepoint rolls back partial work on failure.
 */
public with sharing class BeneficiaryService {
  public class BeneficiaryException extends Exception {
  }

  public static List<Beneficiary__c> getBeneficiaries(Id policyId) {
    if (policyId == null) {
      throw new BeneficiaryException('A policy Id is required.');
    }
    return [
      SELECT
        Id,
        Full_Name__c,
        Relationship__c,
        Designation__c,
        Allocation_Percent__c
      FROM Beneficiary__c
      WHERE Policy__c = :policyId
      WITH USER_MODE
      ORDER BY Designation__c ASC, Allocation_Percent__c DESC, Full_Name__c ASC
    ];
  }

  /**
   * Replaces the policy's beneficiaries with the given list.
   * Rows with an Id are updated, rows without one are inserted, and existing
   * rows missing from the list are deleted.
   */
  public static List<Beneficiary__c> saveBeneficiaries(
    Id policyId,
    List<Beneficiary__c> rows
  ) {
    if (policyId == null) {
      throw new BeneficiaryException('A policy Id is required.');
    }
    List<String> errors = AllocationValidator.validate(rows);
    if (!errors.isEmpty()) {
      throw new BeneficiaryException(String.join(errors, ' '));
    }
    SavePlan plan = buildPlan(policyId, rows);
    applyPlan(plan);
    return getBeneficiaries(policyId);
  }

  /** The DML needed to make the stored rows match the requested rows. */
  private class SavePlan {
    public List<Beneficiary__c> toInsert = new List<Beneficiary__c>();
    public List<Beneficiary__c> toUpdate = new List<Beneficiary__c>();
    public List<Beneficiary__c> toDelete = new List<Beneficiary__c>();
  }

  private static SavePlan buildPlan(Id policyId, List<Beneficiary__c> rows) {
    Map<Id, Beneficiary__c> existing = new Map<Id, Beneficiary__c>(
      getBeneficiaries(policyId)
    );
    SavePlan plan = new SavePlan();
    for (Beneficiary__c row : rows) {
      Beneficiary__c clean = copyEditableFields(row);
      if (row.Id == null) {
        clean.Policy__c = policyId;
        plan.toInsert.add(clean);
      } else if (existing.remove(row.Id) != null) {
        plan.toUpdate.add(clean);
      } else {
        throw new BeneficiaryException(
          'Beneficiary ' + row.Id + ' does not belong to this policy.'
        );
      }
    }
    plan.toDelete.addAll(existing.values());
    return plan;
  }

  /** Copies only the fields the UI may change, so callers cannot set others. */
  private static Beneficiary__c copyEditableFields(Beneficiary__c row) {
    return new Beneficiary__c(
      Id = row.Id,
      Full_Name__c = row.Full_Name__c.trim(),
      Relationship__c = row.Relationship__c,
      Designation__c = row.Designation__c,
      Allocation_Percent__c = row.Allocation_Percent__c
    );
  }

  private static void applyPlan(SavePlan plan) {
    Savepoint sp = Database.setSavepoint();
    try {
      // Delete first so a replaced primary never coexists with its successor.
      Database.delete(plan.toDelete, true, AccessLevel.USER_MODE);
      Database.update(plan.toUpdate, true, AccessLevel.USER_MODE);
      Database.insert(plan.toInsert, true, AccessLevel.USER_MODE);
    } catch (Exception e) {
      Database.rollback(sp);
      throw new BeneficiaryException(
        'Beneficiaries were not saved: ' + e.getMessage()
      );
    }
  }
}
