import { totals, validate, splitEvenly } from "../allocation";
import { reduceError } from "../errors";

const row = (designation, pct, name = "Test Name") => ({
  Full_Name__c: name,
  Designation__c: designation,
  Allocation_Percent__c: pct
});

describe("allocation helpers", () => {
  it("sums primary and contingent separately without float drift", () => {
    const t = totals([
      row("Primary", 33.33),
      row("Primary", 33.33),
      row("Primary", 33.34),
      row("Contingent", 100)
    ]);
    expect(t).toEqual({ primary: 100, contingent: 100 });
  });

  it("accepts a valid primary-only designation", () => {
    expect(validate([row("Primary", 60), row("Primary", 40)])).toEqual([]);
  });

  it("rejects an empty list", () => {
    expect(validate([])).toContain("Add at least one primary beneficiary.");
  });

  it("rejects primary totals other than 100", () => {
    const errors = validate([row("Primary", 50), row("Primary", 40)]);
    expect(errors).toContain(
      "Primary allocations total 90%; they must total 100%."
    );
  });

  it("rejects contingent totals other than 100", () => {
    const errors = validate([row("Primary", 100), row("Contingent", 50)]);
    expect(
      errors.some((e) => e.startsWith("Contingent allocations total 50%"))
    ).toBe(true);
  });

  it("flags blank names and out-of-range values per row", () => {
    const errors = validate([
      row("Primary", 100, " "),
      row("Primary", 0),
      row("Primary", "")
    ]);
    expect(errors).toContain("Row 1: name is required.");
    expect(errors).toContain("Row 2: allocation must be between 0.01 and 100.");
    expect(errors).toContain("Row 3: allocation must be between 0.01 and 100.");
  });

  it("splits evenly and keeps the total at exactly 100", () => {
    const shares = splitEvenly(3);
    expect(shares).toEqual([33.34, 33.33, 33.33]);
    expect(shares.reduce((a, b) => a + b, 0)).toBeCloseTo(100, 10);
    expect(splitEvenly(0)).toEqual([]);
  });

  it("reduces Apex and JS errors to one message", () => {
    expect(reduceError({ body: { message: "Apex said no" } })).toBe(
      "Apex said no"
    );
    expect(reduceError({ body: [{ message: "a" }, { message: "b" }] })).toBe(
      "a, b"
    );
    expect(reduceError(new Error("plain"))).toBe("plain");
    expect(reduceError(undefined)).toBe("Unknown error");
  });
});
