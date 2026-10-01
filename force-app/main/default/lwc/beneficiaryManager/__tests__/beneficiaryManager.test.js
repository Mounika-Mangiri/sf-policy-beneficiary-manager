import { createElement } from "lwc";
import BeneficiaryManager from "c/beneficiaryManager";
import getBeneficiaries from "@salesforce/apex/BeneficiaryController.getBeneficiaries";
import saveBeneficiaries from "@salesforce/apex/BeneficiaryController.saveBeneficiaries";
// The sfdx-lwc-jest toast stub fires this event name.
const SHOW_TOAST = "lightning__showtoast";

jest.mock(
  "@salesforce/apex/BeneficiaryController.getBeneficiaries",
  () => {
    const { createApexTestWireAdapter } = require("@salesforce/sfdx-lwc-jest");
    return { default: createApexTestWireAdapter(jest.fn()) };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/BeneficiaryController.saveBeneficiaries",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const SAMPLE = [
  {
    Id: "a01000000000001AAA",
    Full_Name__c: "Alex Example",
    Relationship__c: "Spouse",
    Designation__c: "Primary",
    Allocation_Percent__c: 100
  },
  {
    Id: "a01000000000002AAA",
    Full_Name__c: "Sam Example",
    Relationship__c: "Child",
    Designation__c: "Contingent",
    Allocation_Percent__c: 100
  }
];

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function mount() {
  const el = createElement("c-beneficiary-manager", { is: BeneficiaryManager });
  el.recordId = "a00000000000001AAA";
  document.body.appendChild(el);
  return el;
}

const saveButton = (el) =>
  el.shadowRoot.querySelector("lightning-button.save-button");
const button = (el, label) =>
  [...el.shadowRoot.querySelectorAll("lightning-button")].find(
    (b) => b.label === label
  );

describe("c-beneficiary-manager", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders one row per beneficiary and shows totals", async () => {
    const el = mount();
    getBeneficiaries.emit(SAMPLE);
    await flush();
    expect(el.shadowRoot.querySelectorAll(".beneficiary-row")).toHaveLength(2);
    expect(el.shadowRoot.querySelector(".totals").textContent).toContain(
      "Primary total: 100%"
    );
    expect(saveButton(el).disabled).toBe(true);
  });

  it("shows the empty state when the policy has no beneficiaries", async () => {
    const el = mount();
    getBeneficiaries.emit([]);
    await flush();
    expect(el.shadowRoot.querySelector(".empty-state")).not.toBeNull();
  });

  it("shows a load error when the wire fails", async () => {
    const el = mount();
    getBeneficiaries.error({ message: "No access" });
    await flush();
    expect(el.shadowRoot.querySelector(".load-error")).not.toBeNull();
  });

  it("blocks save and lists errors when allocations do not total 100", async () => {
    const el = mount();
    getBeneficiaries.emit(SAMPLE);
    await flush();

    button(el, "Add primary").click();
    await flush();
    expect(el.shadowRoot.querySelectorAll(".beneficiary-row")).toHaveLength(3);
    expect(el.shadowRoot.querySelector(".validation-errors")).not.toBeNull();
    expect(saveButton(el).disabled).toBe(true);
  });

  it("saves a valid edit and shows a success toast", async () => {
    saveBeneficiaries.mockResolvedValue(SAMPLE);
    const el = mount();
    const toast = jest.fn();
    el.addEventListener(SHOW_TOAST, toast);
    getBeneficiaries.emit(SAMPLE);
    await flush();

    // Add a second primary, give it a name, then split primary 50/50.
    button(el, "Add primary").click();
    await flush();
    const nameInputs = el.shadowRoot.querySelectorAll(
      'lightning-input[data-field="Full_Name__c"]'
    );
    const newName = nameInputs[nameInputs.length - 1];
    newName.dispatchEvent(
      new CustomEvent("change", { detail: { value: "Jordan Example" } })
    );
    button(el, "Split primary evenly").click();
    await flush();

    expect(saveButton(el).disabled).toBe(false);
    saveButton(el).click();
    await flush();

    expect(saveBeneficiaries).toHaveBeenCalledTimes(1);
    const args = saveBeneficiaries.mock.calls[0][0];
    expect(args.policyId).toBe("a00000000000001AAA");
    const primaries = args.rows.filter((r) => r.Designation__c === "Primary");
    expect(primaries.map((r) => r.Allocation_Percent__c)).toEqual([50, 50]);
    expect(
      args.rows.find((r) => r.Full_Name__c === "Jordan Example").Id
    ).toBeUndefined();
    expect(toast).toHaveBeenCalled();
    expect(toast.mock.calls[0][0].detail.variant).toBe("success");
  });

  it("shows an error toast when the server rejects the save", async () => {
    saveBeneficiaries.mockRejectedValue({
      body: { message: "Primary allocations total 90%" }
    });
    const el = mount();
    const toast = jest.fn();
    el.addEventListener(SHOW_TOAST, toast);
    getBeneficiaries.emit(SAMPLE);
    await flush();

    const pctInputs = el.shadowRoot.querySelectorAll(
      'lightning-input[data-field="Allocation_Percent__c"]'
    );
    // Change the contingent from 100 to 100 (no-op edit) to make the form dirty but valid.
    pctInputs[1].dispatchEvent(
      new CustomEvent("change", { detail: { value: 100 } })
    );
    await flush();
    saveButton(el).click();
    await flush();
    await flush();

    expect(toast).toHaveBeenCalled();
    expect(toast.mock.calls[0][0].detail.variant).toBe("error");
    expect(toast.mock.calls[0][0].detail.message).toBe(
      "Primary allocations total 90%"
    );
  });

  it("removes a row", async () => {
    const el = mount();
    getBeneficiaries.emit(SAMPLE);
    await flush();
    el.shadowRoot.querySelector("lightning-button-icon").click();
    await flush();
    expect(el.shadowRoot.querySelectorAll(".beneficiary-row")).toHaveLength(1);
  });
});
