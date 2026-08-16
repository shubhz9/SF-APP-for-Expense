# Shared Asset Expense Tracker Blueprint

## 1. Product Vision

Build a Salesforce app for tracking assets purchased, financed, maintained, and monetized by multiple people. The app should answer four core questions for each shared asset:

1. **What did we buy?** The shared asset, purchase price, current value, category, and lifecycle status.
2. **Who owns what?** Each participant's ownership percentage and contribution history.
3. **How was it funded and operated?** All cash movements recorded as transactions, including down payments, owner contributions, loans, repayments, expenses, income, returns, and profit distributions.
4. **What is each participant owed or responsible for?** Payouts, loan installments, and ownership-based allocations generated from the transaction ledger.

The design principle is: **`Transaction__c` is the source-of-truth cash ledger, and the other objects provide context, schedules, ownership rules, and settlement records.**

## 2. Existing Data Model Summary

| Object                | Purpose                                                                                                | Parent / Key Relationships                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| `Shared_Asset__c`     | Master record for the jointly owned asset.                                                             | Parent of transactions, loans, and ownership records.                                                      |
| `Asset_Ownership__c`  | Defines each participant's ownership share in an asset over time.                                      | Master-detail to `Shared_Asset__c`; lookup to `Contact`.                                                   |
| `Transaction__c`      | Master cash ledger for every inward and outward movement.                                              | Master-detail to `Shared_Asset__c`; optional lookups to `Contact`, `Loan__c`, and `Loan_Installment__c`.   |
| `Loan__c`             | Captures financing taken for a shared asset.                                                           | Master-detail to `Shared_Asset__c`; parent of loan installments.                                           |
| `Loan_Installment__c` | Planned or actual installment schedule for a loan.                                                     | Master-detail to `Loan__c`; referenced by loan repayment transactions.                                     |
| `Payout__c`           | Participant-level allocation generated from an income or return transaction, and later marked as paid. | Master-detail to the source `Transaction__c`; lookup to the payment `Transaction__c`; lookup to `Contact`. |

## 3. Object Details and Field Intent

### 3.1 `Shared_Asset__c` — Shared Asset

`Shared_Asset__c` is the business container for everything related to a jointly owned asset.

| Field               | Type     | Values / Relationship                            | Blueprint Usage                                                                                       |
| ------------------- | -------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `Category__c`       | Picklist | `Car`, `Property`, `Equipment`, `Other`          | Classifies the asset for reporting, filtering, and future category-specific rules.                    |
| `Purchase_Date__c`  | Date     | —                                                | Date the asset was acquired or planned to be acquired.                                                |
| `Purchase_Price__c` | Currency | —                                                | Baseline purchase cost. Used to compare against contributions, loan principal, and total asset basis. |
| `Current_Value__c`  | Currency | —                                                | Latest valuation. Used for unrealized gain/loss reporting and sale/return calculations.               |
| `Status__c`         | Picklist | `Active`, `Sold`, `Under_Maintenance`, `Planned` | Lifecycle stage that should drive valid transaction types and UI behavior.                            |

### 3.2 `Asset_Ownership__c` — Asset Ownership

`Asset_Ownership__c` defines who owns the asset and what percentage they own. This is the allocation engine for contribution expectations and payout splits.

| Field                     | Type          | Values / Relationship | Blueprint Usage                                                                                                                                  |
| ------------------------- | ------------- | --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Shared_Asset__c`         | Master-detail | `Shared_Asset__c`     | Asset whose ownership is being defined.                                                                                                          |
| `Owner__c`                | Lookup        | `Contact`             | Participant or investor.                                                                                                                         |
| `Ownership_Percentage__c` | Percent       | —                     | Participant's share. Used to split income, returns, expenses, and expected contributions.                                                        |
| `Total_Contribution__c`   | Currency      | —                     | Running or reported total contributed by this participant. Can be calculated from `Transaction__c` records or stored as a denormalized snapshot. |
| `Start_Date__c`           | Date          | —                     | Start of ownership validity.                                                                                                                     |
| `End_Date__c`             | Date          | —                     | End of ownership validity when ownership changes or exits.                                                                                       |
| `Is_Active__c`            | Checkbox      | —                     | Indicates which ownership records are used for current allocations.                                                                              |

### 3.3 `Transaction__c` — Transaction Ledger

`Transaction__c` is the app's master data object. Every actual cash movement should be captured here, even if another object provides the schedule or allocation detail.

| Field                    | Type          | Values / Relationship                           | Blueprint Usage                                                                                        |
| ------------------------ | ------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `Shared_Asset__c`        | Master-detail | `Shared_Asset__c`                               | Required business context for every ledger entry.                                                      |
| `Type__c`                | Picklist      | See Section 4                                   | Key transaction classifier. Drives direction, validations, automations, and reporting.                 |
| `Direction__c`           | Picklist      | `Inward`, `Outward`                             | Whether money is coming into the asset pool or going out of it. Should be auto-derived from `Type__c`. |
| `Amount__c`              | Currency      | —                                               | Transaction amount. Store as a positive value and use `Direction__c` for sign semantics.               |
| `Transaction_Date__c`    | DateTime      | —                                               | Date and time of the cash event.                                                                       |
| `Mode__c`                | Picklist      | `Cash`, `UPI`, `Bank_Transfer`, `Card`, `Other` | Payment method for reconciliation and filtering.                                                       |
| `Owner__c`               | Lookup        | `Contact`                                       | Person who paid, received, contributed, or is associated with the transaction, depending on type.      |
| `Loan__c`                | Lookup        | `Loan__c`                                       | Financing context for disbursements, repayments, and interest payments.                                |
| `Loan_Installment__c`    | Lookup        | `Loan_Installment__c`                           | Schedule line satisfied by a repayment or interest transaction.                                        |
| `Is_System_Generated__c` | Checkbox      | —                                               | Flags transactions created by automation to separate them from manual entries.                         |
| `Notes__c`               | Long text     | —                                               | Human context, references, invoice details, or reconciliation notes.                                   |

### 3.4 `Loan__c` — Loan

`Loan__c` models financing for an asset. It should not replace transactions; it should define the debt agreement and summarize repayment state.

| Field                      | Type          | Values / Relationship           | Blueprint Usage                                                                                 |
| -------------------------- | ------------- | ------------------------------- | ----------------------------------------------------------------------------------------------- |
| `Shared_Asset__c`          | Master-detail | `Shared_Asset__c`               | Asset financed by the loan.                                                                     |
| `Principal_Amount__c`      | Currency      | —                               | Original borrowed amount. Typically matched by a `Loan_Disbursement` transaction.               |
| `Outstanding_Principal__c` | Currency      | —                               | Remaining principal after repayments. Can be calculated from loan installments or transactions. |
| `Interest_Rate__c`         | Percent       | —                               | Contractual interest rate for EMI planning and reporting.                                       |
| `EMI_Amount__c`            | Currency      | —                               | Expected installment amount.                                                                    |
| `Start_Date__c`            | Date          | —                               | Loan start date.                                                                                |
| `End_Date__c`              | Date          | —                               | Expected or actual loan end date.                                                               |
| `Status__c`                | Picklist      | `Active`, `Closed`, `Defaulted` | Loan lifecycle state.                                                                           |

### 3.5 `Loan_Installment__c` — Loan Installment

`Loan_Installment__c` is the loan repayment schedule and status tracker.

| Field                    | Type          | Values / Relationship                   | Blueprint Usage                       |
| ------------------------ | ------------- | --------------------------------------- | ------------------------------------- |
| `Loan__c`                | Master-detail | `Loan__c`                               | Parent loan.                          |
| `Due_Date__c`            | Date          | —                                       | Installment due date.                 |
| `Amount__c`              | Currency      | —                                       | Total EMI amount.                     |
| `Principal_Component__c` | Currency      | —                                       | Principal portion of the installment. |
| `Interest_Component__c`  | Currency      | —                                       | Interest portion of the installment.  |
| `Status__c`              | Picklist      | `Planned`, `Pending`, `Paid`, `Overdue` | Repayment schedule status.            |
| `Paid_Date__c`           | Date          | —                                       | Date the installment was paid.        |

### 3.6 `Payout__c` — Payout

`Payout__c` represents a participant's calculated share from an asset income, return, or distribution event.

| Field                     | Type          | Values / Relationship    | Blueprint Usage                                                                           |
| ------------------------- | ------------- | ------------------------ | ----------------------------------------------------------------------------------------- |
| `Transaction__c`          | Master-detail | Source `Transaction__c`  | Income or return transaction that generated this payout allocation.                       |
| `Owner__c`                | Lookup        | `Contact`                | Participant receiving the payout.                                                         |
| `Ownership_Percentage__c` | Percent       | —                        | Ownership share used at the time of calculation. Snapshot this value to preserve history. |
| `Amount__c`               | Currency      | —                        | Participant's allocated payout amount.                                                    |
| `Is_Paid__c`              | Checkbox      | —                        | Settlement flag.                                                                          |
| `Payment_Transaction__c`  | Lookup        | Payment `Transaction__c` | Actual cash transaction that paid this payout.                                            |
| `Remarks__c`              | Long text     | —                        | Notes, payment reference, exceptions, or manual adjustment reason.                        |

## 4. Transaction Type Blueprint

`Type__c` should be the central driver for direction, required fields, and downstream automation.

| Type                  | Direction | Required Context                                                                   | Meaning                                                               | Expected Automation                                                              |
| --------------------- | --------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `Down_Payment`        | Inward    | `Shared_Asset__c`, `Owner__c`                                                      | Initial amount paid by one or more owners toward purchase.            | Add to participant contribution and asset funding summary.                       |
| `Owner_Contribution`  | Inward    | `Shared_Asset__c`, `Owner__c`                                                      | Additional owner funding for purchase, EMI, maintenance, or reserves. | Add to participant contribution. Optionally offset expense responsibility.       |
| `Loan_Disbursement`   | Inward    | `Shared_Asset__c`, `Loan__c`                                                       | Loan money received into the asset pool.                              | Increase available funding; initialize or validate loan principal.               |
| `Loan_Repayment`      | Outward   | `Shared_Asset__c`, `Loan__c`, optionally `Loan_Installment__c`                     | Principal repayment made to lender.                                   | Reduce outstanding principal; mark installment paid if full repayment completed. |
| `Interest_Payment`    | Outward   | `Shared_Asset__c`, `Loan__c`, optionally `Loan_Installment__c`                     | Interest paid to lender.                                              | Track financing cost; optionally mark installment interest component paid.       |
| `Maintenance_Expense` | Outward   | `Shared_Asset__c`, optionally `Owner__c`                                           | Repair or upkeep cost.                                                | Allocate cost by ownership percentage or by payer reimbursement rule.            |
| `Insurance`           | Outward   | `Shared_Asset__c`, optionally `Owner__c`                                           | Insurance premium or related expense.                                 | Allocate cost by ownership percentage.                                           |
| `Income_From_Asset`   | Inward    | `Shared_Asset__c`                                                                  | Income generated by the asset, such as rent or usage revenue.         | Generate `Payout__c` rows for active owners based on ownership percentage.       |
| `Return`              | Inward    | `Shared_Asset__c`                                                                  | Capital return, refund, sale proceeds, or recovered amount.           | Generate `Payout__c` rows for active owners based on ownership percentage.       |
| `Profit_Distribution` | Outward   | `Shared_Asset__c`, `Owner__c`, optionally `Payout__c` via `Payment_Transaction__c` | Actual payment of allocated profit/return to an owner.                | Mark related payout paid and link `Payment_Transaction__c`.                      |
| `Other_Expense`       | Outward   | `Shared_Asset__c`                                                                  | Any other asset-related outflow.                                      | Include in cashflow and allocation reporting.                                    |
| `Other_Income`        | Inward    | `Shared_Asset__c`                                                                  | Any other asset-related inflow.                                       | Include in cashflow reporting; optionally allocate to owners if configured.      |

## 5. Direction Rules

The current Apex implementation centralizes type behavior in `TransactionTypeConfig`. That class is the source for direction mapping, required context, payout generation, contribution rollups, loan principal repayment behavior, and profit distribution behavior.

- **Inward:** `Down_Payment`, `Owner_Contribution`, `Loan_Disbursement`, `Income_From_Asset`, `Return`, `Other_Income`
- **Outward:** `Loan_Repayment`, `Interest_Payment`, `Maintenance_Expense`, `Insurance`, `Profit_Distribution`, `Other_Expense`

Recommended product rule:

- Users should select `Type__c`.
- The app should set `Direction__c` automatically before save.
- Users should not manually override `Direction__c` unless an admin-only exception is needed.
- Reports should treat inward amounts as positive and outward amounts as negative for net cashflow.

## 6. Core Business Workflows

### 6.1 Asset Purchase With Owner Contributions

1. Create `Shared_Asset__c` with purchase details and status `Planned` or `Active`.
2. Create active `Asset_Ownership__c` records for each participant.
3. Enter `Down_Payment` or `Owner_Contribution` transactions against the asset and contributing owner.
4. Compare total owner contributions plus loan disbursements against `Purchase_Price__c`.
5. Move asset status to `Active` when purchase funding and ownership are finalized.

### 6.2 Asset Purchase With Loan

1. Create `Loan__c` under the shared asset.
2. Enter a `Loan_Disbursement` transaction linked to the loan.
3. Generate or import `Loan_Installment__c` schedule records.
4. For each payment, enter `Loan_Repayment` and/or `Interest_Payment` transactions linked to the loan and installment.
5. Update installment status and loan outstanding principal from transaction totals.
6. Set loan status to `Closed` when outstanding principal reaches zero.

### 6.3 Income or Return Allocation

1. Enter an `Income_From_Asset` or `Return` transaction for the asset.
2. Automation queries active `Asset_Ownership__c` records.
3. For each active owner, create a `Payout__c` record:
   - `Payout__c.Amount__c = Transaction__c.Amount__c * Ownership_Percentage__c / 100`
   - `Payout__c.Is_Paid__c = false`
   - Snapshot `Ownership_Percentage__c` from the ownership record.
4. When money is actually distributed, create a `Profit_Distribution` transaction for the owner.
5. Link the payout to the payment transaction via `Payment_Transaction__c` and set `Is_Paid__c = true`.

Current MVP behavior:

- Active ownership for the asset must total exactly 100% before financial transactions can be saved.
- Payout percentages are stored as snapshots and are not recalculated when ownership changes later.
- Partial payout settlement is not supported. A `Profit_Distribution` transaction must exactly match one or more unpaid payouts for the same owner and asset.
- The payment transaction is linked back to the settled payout through `Payout__c.Payment_Transaction__c`.

### 6.4 Expense Allocation and Reimbursement

The current metadata supports expense capture, but a reimbursement allocation object does not yet exist. Recommended approach:

1. Capture each expense as `Maintenance_Expense`, `Insurance`, or `Other_Expense`.
2. If one owner paid the expense, store that owner in `Transaction__c.Owner__c`.
3. Calculate each owner's responsibility by ownership percentage.
4. Report net position per owner as: contributions + paid expenses - expected ownership share of costs - payouts received.
5. If detailed payable tracking is required, add a future `Expense_Allocation__c` object similar to `Payout__c`.

## 7. Recommended Calculations and KPIs

### 7.1 Asset-Level Metrics

| Metric                      | Formula / Logic                                                                      |
| --------------------------- | ------------------------------------------------------------------------------------ |
| Total Inward Cash           | Sum `Transaction__c.Amount__c` where `Direction__c = Inward`.                        |
| Total Outward Cash          | Sum `Transaction__c.Amount__c` where `Direction__c = Outward`.                       |
| Net Cash Position           | Total inward cash - total outward cash.                                              |
| Total Owner Contributions   | Sum `Down_Payment` + `Owner_Contribution`.                                           |
| Total Loan Funding          | Sum `Loan_Disbursement`.                                                             |
| Total Loan Principal Repaid | Sum `Loan_Repayment`.                                                                |
| Total Interest Cost         | Sum `Interest_Payment`.                                                              |
| Operating Expense           | Sum `Maintenance_Expense` + `Insurance` + `Other_Expense`.                           |
| Asset Gain / Loss           | `Current_Value__c - Purchase_Price__c`, optionally adjusted for income and expenses. |

### 7.2 Owner-Level Metrics

| Metric                         | Formula / Logic                                                                                                 |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------- |
| Ownership Share                | Active `Asset_Ownership__c.Ownership_Percentage__c`.                                                            |
| Actual Contributions           | Sum owner-linked `Down_Payment` and `Owner_Contribution` transactions.                                          |
| Expected Contribution          | Asset cost or expense amount multiplied by ownership percentage.                                                |
| Contribution Surplus / Deficit | Actual contributions - expected contribution.                                                                   |
| Earned Payouts                 | Sum `Payout__c.Amount__c` for owner.                                                                            |
| Paid Payouts                   | Sum paid `Payout__c.Amount__c` where `Is_Paid__c = true`.                                                       |
| Pending Payouts                | Sum unpaid `Payout__c.Amount__c` where `Is_Paid__c = false`.                                                    |
| Net Owner Position             | Actual contributions + owner-paid expenses - expected costs - paid payouts, adjusted by your settlement policy. |

## 8. Validation Rules to Add

1. **Ownership total validation:** Active ownership percentages cannot exceed 100% on ownership save, and transactions are blocked until active ownership totals exactly 100%.
2. **Single active ownership per owner per asset:** A contact cannot have overlapping active ownership records for the same asset.
3. **Transaction amount validation:** `Amount__c` must be positive; direction supplies sign semantics.
4. **Type-specific required fields:**
   - Loan transaction types require `Loan__c`.
   - Loan installment repayment transactions require `Loan__c` when an installment is selected.
   - Owner contribution and profit distribution types require `Owner__c`.
5. **Loan integrity:** Closed loans reject new loan transactions, and principal repayment cannot exceed outstanding principal.
6. **Payout integrity:** Paid payout financial details cannot be changed, and payment transactions must be profit distributions for the same owner.
7. **Closed asset restriction:** Prevent new operational transactions when `Shared_Asset__c.Status__c = Sold`, except final return, payout, or correction entries. This remains a future rule.

## 9. Automation Blueprint

### 9.1 Already Represented in Apex Design

- Auto-derive `Transaction__c.Direction__c` from `Transaction__c.Type__c` using `TransactionTypeConfig`.
- Validate transaction context before save, including active ownership readiness, positive amounts, owner/loan requirements, closed loans, overpayment, and exact payout settlement.
- Generate `Payout__c` records for `Income_From_Asset` and `Return` transactions based on active ownership percentages.
- Delete and regenerate payouts when the source income or return transaction changes, preventing duplicate payout rows.
- Mark payouts paid from matching `Profit_Distribution` transactions and link the payment transaction.
- Roll up owner contributions from contribution transactions.
- Roll up loan principal repayment and installment status from linked transactions.

### 9.2 Next Automations to Implement

| Priority | Automation                                                                            | Trigger / Timing                                       | Result                                               |
| -------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------ | ---------------------------------------------------- |
| 1        | Add explicit expense allocation records if settlement tracking is required.           | `Transaction__c` after save for expense types          | Owner-level liability reporting becomes explicit.    |
| 2        | Add asset KPI rollup fields or report-backed summaries.                              | Transaction recalculation or reports                   | Asset cash position is visible without manual work.  |
| 3        | Add dashboard and report metadata.                                                    | Reports and dashboards                                 | MVP has packaged operational analytics.              |
| 4        | Add sold-asset transaction restrictions.                                              | `Transaction__c` before save                           | Closed asset lifecycle is protected.                 |
| 5        | Use transaction date for historical ownership selection.                              | Payout generation                                      | Ownership changes are fully effective-date aware.    |

## 10. Reporting and UI Blueprint

### 10.1 Shared Asset Record Page

Recommended sections:

- Asset summary: category, purchase price, current value, status.
- Ownership split: active owners and percentages.
- Funding summary: owner contributions, loan disbursement, purchase funding gap.
- Cashflow summary: total inward, total outward, net cash.
- Loan summary: active loans, outstanding principal, upcoming installments.
- Payout summary: pending and paid payouts.
- Transaction timeline: all transactions ordered by `Transaction_Date__c`.

### 10.2 Transaction Entry UX

Recommended behavior:

- User chooses asset and transaction type first.
- App shows only context fields relevant to that type.
- Direction is read-only and derived.
- Loan fields appear for loan-related transaction types.
- Owner field is required for owner-specific transactions.
- Notes and mode remain optional but encouraged for reconciliation.

### 10.3 Key Reports

1. **Asset Net Cashflow Report** by shared asset, type, and month.
2. **Owner Contribution vs Ownership Obligation Report** by asset and owner.
3. **Pending Payouts Report** by owner and asset.
4. **Loan Repayment Schedule Report** showing pending, overdue, and paid installments.
5. **Asset Profitability Report** combining income, expenses, financing cost, and current value.

## 11. Example Scenario

Four people buy a property for 1,000,000 with equal 25% ownership:

1. Create one `Shared_Asset__c` property record with purchase price 1,000,000.
2. Create four active `Asset_Ownership__c` records at 25% each.
3. Two owners pay down payments of 100,000 each:
   - Create two `Down_Payment` transactions with `Owner__c` populated.
4. A bank disburses a loan of 800,000:
   - Create one `Loan__c` and one `Loan_Disbursement` transaction.
5. The property earns rent of 40,000:
   - Create one `Income_From_Asset` transaction.
   - Automation creates four payout records of 10,000 each.
6. The app shows:
   - Asset funding: 200,000 owner contribution + 800,000 loan.
   - Ownership: 25% each.
   - Pending payouts: 10,000 for each owner.
   - Loan outstanding principal and next installment due.

## 12. Implementation Notes and Risks

- The `Transaction__c` object should remain the immutable-style ledger. Prefer correction transactions over editing historical financial records after settlement.
- Snapshot values such as `Payout__c.Ownership_Percentage__c` are important because ownership percentages may change later.
- Current payout generation uses active ownership records. If ownership can change over time, payout generation should use ownership records active on `Transaction_Date__c`, not just `Is_Active__c` on the current date.
- If expenses must be settled between owners, add an explicit expense allocation object rather than overloading `Payout__c`.
- If loans can have multiple lenders or owner-funded loans, add lender/contact relationships to `Loan__c` or introduce a `Loan_Party__c` junction object.
- Reports should clearly distinguish cash received into the asset pool from cash distributed to owners.

## 13. Audit Status as of Current MVP Pass

Done:

- Core custom objects and relationships exist for shared assets, ownership, transactions, loans, installments, and payouts.
- Thin triggers delegate to domain classes.
- Domain and service classes handle validation and automation for the central ledger, ownership, loans, installments, and payouts.
- Selectors exist for the core objects.
- Page layouts, tabs, Lightning record pages, app metadata, a flow, and two permission sets are present.
- Apex tests exist for the core service behavior and were extended for stricter transaction validation.

Partially done:

- Loan automation supports principal rollups and installment status updates, but does not generate a full amortized schedule from loan terms.
- Owner financial position can be derived from ledger/payout records, but no packaged owner position service/report dashboard is implemented.
- Asset financial position can be derived from transactions, but no packaged asset KPI fields/dashboard are implemented.

Missing:

- `Expense_Allocation__c` or equivalent detailed expense settlement records.
- Packaged Salesforce reports and dashboard metadata.
- Full effective-date-aware ownership selection for historical payout generation.
- Sold-asset transaction restrictions.
- CI workflow for formatting, linting, LWC tests, and deploy validation.

Verification note:

- Local npm checks require project dependencies. In the current environment, `npm install` timed out and left no `node_modules`.
- Salesforce CLI is installed and the default org alias is `TrailheadDev`, but deploy validation failed with `EACCES` while calling the Salesforce metadata SOAP endpoint. Apex tests and deployment validation still require a reachable authenticated org.

## 14. Suggested Build Phases

### Phase 1 — Ledger Foundation

- Finalize transaction type semantics.
- Auto-set direction from type.
- Add type-specific validations.
- Build asset cashflow and owner contribution reports.

### Phase 2 — Ownership and Payout Automation

- Validate ownership totals.
- Generate payouts for income and return transactions.
- Add payout settlement flow using `Profit_Distribution` transactions.

### Phase 3 — Loan Automation

- Generate loan installments.
- Link repayments to installments.
- Roll up outstanding principal and loan status.

### Phase 4 — Advanced Settlement

- Add expense allocation if needed.
- Add owner net position dashboard.
- Add asset sale/exit workflow.
- Add audit controls for locked or reconciled transactions.
