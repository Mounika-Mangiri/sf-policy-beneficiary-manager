#!/usr/bin/env bash
# Creates a scratch org, deploys the project, assigns the permission set and loads synthetic data.
# Requires the Salesforce CLI (sf) and an authorized Dev Hub.
set -euo pipefail
ALIAS="${1:-beneficiary-demo}"

sf org create scratch --definition-file config/project-scratch-def.json --alias "$ALIAS" --set-default --duration-days 7 --wait 15
sf project deploy start --target-org "$ALIAS" --wait 20
sf org assign permset --name Beneficiary_Manager --target-org "$ALIAS"
sf data import tree --plan data/sample-data-plan.json --target-org "$ALIAS"
sf apex run test --target-org "$ALIAS" --code-coverage --result-format human --wait 20
sf org open --target-org "$ALIAS" --path lightning/o/Policy__c/list
