/**
 * Validates beneficiary allocations for one policy.
 *
 * Rules (mirrors typical life/annuity servicing requirements):
 *  - at least one Primary beneficiary
 *  - Primary allocations total exactly 100
 *  - Contingent allocations, when present, total exactly 100
 *  - every allocation is between 0.01 and 100
 *  - every beneficiary has a name
 *
 * Pure logic with no SOQL or DML, so it is unit-tested without data setup.
 */
public with sharing class AllocationValidator {
  public static final String PRIMARY = 'Primary';
  public static final String CONTINGENT = 'Contingent';
  private static final Decimal FULL = 100;

  /** Running totals per designation. */
  private class Totals {
    public Decimal primary = 0;
    public Decimal contingent = 0;
    public Integer primaryCount = 0;
    public Integer contingentCount = 0;

    public void add(Beneficiary__c row) {
      if (row.Designation__c == CONTINGENT) {
        contingent += row.Allocation_Percent__c;
        contingentCount++;
      } else {
        primary += row.Allocation_Percent__c;
        primaryCount++;
      }
    }
  }

  public static List<String> validate(List<Beneficiary__c> rows) {
    List<String> errors = new List<String>();
    if (rows == null || rows.isEmpty()) {
      errors.add('Add at least one primary beneficiary.');
      return errors;
    }
    Totals sums = new Totals();
    for (Integer i = 0; i < rows.size(); i++) {
      Beneficiary__c row = rows[i];
      errors.addAll(checkRow(row, 'Row ' + (i + 1)));
      if (isValidPercent(row.Allocation_Percent__c)) {
        sums.add(row);
      }
    }
    errors.addAll(checkTotals(sums));
    return errors;
  }

  private static Boolean isValidPercent(Decimal pct) {
    return pct != null && pct > 0 && pct <= FULL;
  }

  private static List<String> checkRow(Beneficiary__c row, String label) {
    List<String> errors = new List<String>();
    if (String.isBlank(row.Full_Name__c)) {
      errors.add(label + ': name is required.');
    }
    if (!isValidPercent(row.Allocation_Percent__c)) {
      errors.add(label + ': allocation must be between 0.01 and 100.');
    }
    return errors;
  }

  private static List<String> checkTotals(Totals sums) {
    List<String> errors = new List<String>();
    if (sums.primaryCount == 0) {
      errors.add('Add at least one primary beneficiary.');
    } else if (sums.primary != FULL) {
      errors.add(
        'Primary allocations total ' + sums.primary + '%; they must total 100%.'
      );
    }
    if (sums.contingentCount > 0 && sums.contingent != FULL) {
      errors.add(
        'Contingent allocations total ' +
          sums.contingent +
          '%; they must total 100%.'
      );
    }
    return errors;
  }
}
