# CoAsset Shared Expense Tracker

CoAsset is a Salesforce app for tracking assets purchased, financed, maintained, and monetized by multiple people. It helps users understand what was bought, who owns what percentage, how money moved in and out, and what each participant is owed or responsible for.

The core idea is that `Transaction__c` acts as the source-of-truth cash ledger. Other records provide business context around that ledger: shared assets, ownership percentages, loans, loan installments, and payout allocations.

## What This App Does

- Tracks shared assets such as property, cars, equipment, or other jointly owned purchases.
- Stores ownership splits for each asset through `Asset_Ownership__c`.
- Records all money movement through `Transaction__c`, including owner contributions, down payments, loan disbursements, loan repayments, maintenance expenses, income, returns, and profit distributions.
- Supports loan-backed asset purchases through `Loan__c` and `Loan_Installment__c`.
- Creates participant-level payout records through `Payout__c` for income or return events.
- Provides Salesforce tabs, layouts, Lightning record pages, permission sets, Apex services, and automation for the app.

For the detailed product and automation blueprint, see [docs/shared-expense-tracker-blueprint.md](docs/shared-expense-tracker-blueprint.md).

## Main Salesforce Objects

| Object                | Purpose                                                                   |
| --------------------- | ------------------------------------------------------------------------- |
| `Shared_Asset__c`     | Master record for a jointly owned asset.                                  |
| `Asset_Ownership__c`  | Defines each participant's ownership percentage for an asset.             |
| `Transaction__c`      | Ledger for every inward and outward cash movement.                        |
| `Loan__c`             | Financing record for an asset.                                            |
| `Loan_Installment__c` | Repayment schedule and status tracker for a loan.                         |
| `Payout__c`           | Owner-level payout allocation created from income or return transactions. |

## Project Structure

```text
force-app/main/default/
  applications/       Salesforce app metadata
  classes/            Apex domain, service, selector, utility, and fflib classes
  flows/              Salesforce Flow automation
  flexipages/         Lightning record pages and utility bar
  layouts/            Page layouts for custom objects
  objects/            Custom object and field metadata
  permissionsets/     App permission sets
  tabs/               Custom object tabs
  triggers/           Apex triggers

docs/
  shared-expense-tracker-blueprint.md
```

## Prerequisites

Install these before setting up the project:

- Salesforce CLI.
- Node.js and npm.
- Access to a Salesforce Dev Hub, scratch org, sandbox, or developer org.
- Git.

Check your local tools:

```bash
sf --version
node --version
npm --version
```

## Setup

Clone the repository and install local development dependencies:

```bash
git clone <repository-url>
cd SF-APP-for-Expense
npm install
```

Authorize your Salesforce org:

```bash
sf org login web --alias expense-dev
```

If you are using a Dev Hub and want a scratch org, authorize the Dev Hub and create the org:

```bash
sf org login web --set-default-dev-hub --alias my-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --alias expense-scratch --duration-days 30 --set-default
```

Deploy the metadata:

```bash
sf project deploy start --source-dir force-app
```

Assign an app permission set:

```bash
sf org assign permset --name Expense_Admin_CRUD
```

Open the org:

```bash
sf org open
```

In Salesforce, open the App Launcher and select **CoAsset**.

## Using the App

1. Create a `Shared Asset` record with purchase details and status.
2. Create `Asset Ownership` records for each participant and their ownership percentage.
3. Ensure active ownership for the asset totals 100% before recording financial transactions.
4. Add `Transaction` records for owner contributions, down payments, expenses, loan activity, income, returns, or distributions.
5. For financed purchases, create a `Loan` record and related `Loan Installment` records.
6. Review `Payout` records generated or maintained for owner-level income and return allocations.

Transaction type drives business behavior. For example, `Income_From_Asset` and `Return` represent inward cash events that can be allocated to owners, while `Loan_Repayment`, `Interest_Payment`, `Maintenance_Expense`, and `Profit_Distribution` represent outward cash events.

## Implemented MVP Automation

- `TransactionTypeConfig` centralizes transaction type rules, including direction, required asset/owner/loan context, contribution behavior, payout generation, repayment behavior, and distribution behavior.
- `Transaction__c.Direction__c` is derived before insert and update from `Transaction__c.Type__c`; users should not treat direction as an editable business input.
- Transaction validation requires positive amounts, supported transaction types, required context fields, active ownership totaling 100%, valid loan status, no principal overpayment, and exact full-payout matching for profit distributions.
- `Income_From_Asset` and `Return` transactions generate unpaid `Payout__c` rows for active owners using the ownership percentage as a historical snapshot.
- `Profit_Distribution` transactions mark matching unpaid payout rows as paid and link `Payout__c.Payment_Transaction__c`. Partial payout settlement is not supported in this MVP; a distribution must exactly match one or more unpaid payouts for that owner and asset.
- Loan repayment transactions roll up outstanding principal and close the loan when principal reaches zero. Interest payments do not reduce principal.
- Loan installment status is recalculated from linked repayment and interest transactions.
- Owner contribution totals are rolled up to active `Asset_Ownership__c` records from `Down_Payment` and `Owner_Contribution` transactions.

## Current Limitations

- Expense allocation is still implicit in the ledger and reports; there is no `Expense_Allocation__c` object in this repository.
- Asset-level financial KPI fields and dashboard/report metadata are not yet implemented.
- Ownership validation prevents active totals above 100% on ownership records and blocks transactions until active ownership totals exactly 100%. This allows progressive ownership setup while protecting the ledger.
- Automatic date-effective ownership selection for historical payout generation is not implemented; payout generation uses currently active ownership records and snapshots their percentages.
- Full Salesforce deployment validation and Apex test execution require an authenticated org.

## Development Commands

Format the project:

```bash
npm run prettier
```

Check formatting:

```bash
npm run prettier:verify
```

Run LWC unit tests:

```bash
npm test
```

Run LWC linting:

```bash
npm run lint
```

Run Apex tests in the default org:

```bash
sf apex run test --test-level RunLocalTests --wait 10 --result-format human
```

## Permission Sets

The project includes two permission sets:

- `Expense_Admin_CRUD`: Admin-style access for configuring and managing app records.
- `Expense_ReadOnly`: Read-only access for users who need visibility into shared assets, transactions, loans, and payouts.

Assign the correct permission set after deployment based on the user's role.

## Notes for Future Builders

- Keep `Transaction__c` as the primary ledger for cash movement.
- Derive `Direction__c` from `Type__c` instead of relying on manual entry.
- Use `Asset_Ownership__c` as the source for ownership-based payout and cost allocation.
- Preserve historical payout percentages on `Payout__c` so ownership changes do not rewrite past allocations.
- See the blueprint document before changing object relationships, transaction types, or automation rules.
