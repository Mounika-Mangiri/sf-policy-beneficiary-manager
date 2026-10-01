import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getBeneficiaries from "@salesforce/apex/BeneficiaryController.getBeneficiaries";
import saveBeneficiaries from "@salesforce/apex/BeneficiaryController.saveBeneficiaries";
import {
  PRIMARY,
  CONTINGENT,
  totals,
  validate,
  splitEvenly
} from "./allocation";
import { reduceError } from "./errors";

let tempKey = 0;
const nextKey = () => `new-${++tempKey}`;

export default class BeneficiaryManager extends LightningElement {
  @api recordId;

  rows = [];
  loadError;
  isSaving = false;
  isDirty = false;
  wiredResult;

  designationOptions = [
    { label: PRIMARY, value: PRIMARY },
    { label: CONTINGENT, value: CONTINGENT }
  ];

  relationshipOptions = [
    "Spouse",
    "Child",
    "Parent",
    "Sibling",
    "Trust",
    "Other"
  ].map((v) => ({ label: v, value: v }));

  @wire(getBeneficiaries, { policyId: "$recordId" })
  wiredBeneficiaries(result) {
    this.wiredResult = result;
    if (result.data) {
      this.rows = result.data.map((r) => ({ ...r, key: r.Id }));
      this.loadError = undefined;
      this.isDirty = false;
    } else if (result.error) {
      this.loadError = reduceError(result.error);
      this.rows = [];
    }
  }

  get primaryTotal() {
    return totals(this.rows).primary;
  }

  get contingentTotal() {
    return totals(this.rows).contingent;
  }

  get errors() {
    return this.isDirty ? validate(this.rows) : [];
  }

  get hasErrors() {
    return this.errors.length > 0;
  }

  get saveDisabled() {
    return !this.isDirty || this.isSaving || validate(this.rows).length > 0;
  }

  get isEmpty() {
    return !this.loadError && this.rows.length === 0;
  }

  handleAdd(event) {
    const designation = event.target.dataset.designation || PRIMARY;
    this.rows = [
      ...this.rows,
      {
        key: nextKey(),
        Full_Name__c: "",
        Relationship__c: "Other",
        Designation__c: designation,
        Allocation_Percent__c: null
      }
    ];
    this.isDirty = true;
  }

  handleRemove(event) {
    const key = event.target.dataset.key;
    this.rows = this.rows.filter((r) => r.key !== key);
    this.isDirty = true;
  }

  handleFieldChange(event) {
    const { key, field } = event.target.dataset;
    const value = event.detail.value;
    this.rows = this.rows.map((r) =>
      r.key === key ? { ...r, [field]: value } : r
    );
    this.isDirty = true;
  }

  handleSplitPrimary() {
    const primaries = this.rows.filter((r) => r.Designation__c !== CONTINGENT);
    const shares = splitEvenly(primaries.length);
    let i = 0;
    this.rows = this.rows.map((r) =>
      r.Designation__c !== CONTINGENT
        ? { ...r, Allocation_Percent__c: shares[i++] }
        : r
    );
    this.isDirty = true;
  }

  handleCancel() {
    this.isDirty = false;
    return refreshApex(this.wiredResult);
  }

  async handleSave() {
    if (validate(this.rows).length > 0) {
      return;
    }
    this.isSaving = true;
    const payload = this.rows.map((r) => {
      const record = {
        Full_Name__c: r.Full_Name__c,
        Relationship__c: r.Relationship__c,
        Designation__c: r.Designation__c,
        Allocation_Percent__c: Number(r.Allocation_Percent__c)
      };
      if (r.Id) {
        record.Id = r.Id;
      }
      return record;
    });
    try {
      await saveBeneficiaries({ policyId: this.recordId, rows: payload });
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Beneficiaries saved",
          message: "Designations were updated.",
          variant: "success"
        })
      );
      this.isDirty = false;
      await refreshApex(this.wiredResult);
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Beneficiaries were not saved",
          message: reduceError(error),
          variant: "error",
          mode: "sticky"
        })
      );
    } finally {
      this.isSaving = false;
    }
  }
}
