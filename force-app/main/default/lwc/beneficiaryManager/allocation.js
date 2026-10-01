/**
 * Pure allocation helpers shared by the component and its Jest tests.
 * Mirrors the server-side rules in AllocationValidator.cls so the user sees
 * problems before saving; the server remains the source of truth.
 */
export const PRIMARY = "Primary";
export const CONTINGENT = "Contingent";

const toCents = (value) => Math.round(Number(value) * 100);

export function totals(rows) {
  let primary = 0;
  let contingent = 0;
  (rows || []).forEach((row) => {
    const cents = toCents(row.Allocation_Percent__c);
    if (!Number.isFinite(cents)) {
      return;
    }
    if (row.Designation__c === CONTINGENT) {
      contingent += cents;
    } else {
      primary += cents;
    }
  });
  return { primary: primary / 100, contingent: contingent / 100 };
}

export function validate(rows) {
  const errors = [];
  const list = rows || [];
  if (!list.some((r) => r.Designation__c !== CONTINGENT)) {
    errors.push("Add at least one primary beneficiary.");
  }
  list.forEach((row, i) => {
    const label = `Row ${i + 1}`;
    if (!row.Full_Name__c || !String(row.Full_Name__c).trim()) {
      errors.push(`${label}: name is required.`);
    }
    const pct = Number(row.Allocation_Percent__c);
    if (
      row.Allocation_Percent__c === "" ||
      row.Allocation_Percent__c === null ||
      row.Allocation_Percent__c === undefined ||
      !Number.isFinite(pct) ||
      pct <= 0 ||
      pct > 100
    ) {
      errors.push(`${label}: allocation must be between 0.01 and 100.`);
    }
  });
  const t = totals(list);
  const hasPrimary = list.some((r) => r.Designation__c !== CONTINGENT);
  const hasContingent = list.some((r) => r.Designation__c === CONTINGENT);
  if (hasPrimary && t.primary !== 100) {
    errors.push(
      `Primary allocations total ${t.primary}%; they must total 100%.`
    );
  }
  if (hasContingent && t.contingent !== 100) {
    errors.push(
      `Contingent allocations total ${t.contingent}%; they must total 100%.`
    );
  }
  return errors;
}

/** Splits 100% evenly across n rows, putting the rounding remainder on the first row. */
export function splitEvenly(n) {
  if (!n || n < 1) {
    return [];
  }
  const base = Math.floor(10000 / n) / 100;
  const shares = Array(n).fill(base);
  shares[0] = Math.round((100 - base * (n - 1)) * 100) / 100;
  return shares;
}
