public with sharing class TransactionTypeConfig {
    public class TransactionTypeRule {
        public String typeName { get; private set; }
        public String direction { get; private set; }
        public Boolean requiresAsset { get; private set; }
        public Boolean requiresOwner { get; private set; }
        public Boolean requiresLoan { get; private set; }
        public Boolean generatesPayout { get; private set; }
        public Boolean ownerContribution { get; private set; }
        public Boolean loanPrincipalRepayment { get; private set; }
        public Boolean profitDistribution { get; private set; }
        public Boolean expenseAllocation { get; private set; }

        private TransactionTypeRule(
            String typeName,
            String direction,
            Boolean requiresAsset,
            Boolean requiresOwner,
            Boolean requiresLoan,
            Boolean generatesPayout,
            Boolean ownerContribution,
            Boolean loanPrincipalRepayment,
            Boolean profitDistribution,
            Boolean expenseAllocation
        ) {
            this.typeName = typeName;
            this.direction = direction;
            this.requiresAsset = requiresAsset;
            this.requiresOwner = requiresOwner;
            this.requiresLoan = requiresLoan;
            this.generatesPayout = generatesPayout;
            this.ownerContribution = ownerContribution;
            this.loanPrincipalRepayment = loanPrincipalRepayment;
            this.profitDistribution = profitDistribution;
            this.expenseAllocation = expenseAllocation;
        }
    }

    private static final Map<String, TransactionTypeRule> RULES_BY_TYPE = buildRules();

    public static TransactionTypeRule ruleFor(String transactionType) {
        return RULES_BY_TYPE.get(transactionType);
    }

    public static Boolean isSupported(String transactionType) {
        return RULES_BY_TYPE.containsKey(transactionType);
    }

    public static Boolean requiresOwner(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.requiresOwner;
    }

    public static Boolean requiresLoan(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.requiresLoan;
    }

    public static Boolean requiresAsset(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.requiresAsset;
    }

    public static Boolean generatesPayout(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.generatesPayout;
    }

    public static Boolean isOwnerContribution(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.ownerContribution;
    }

    public static Boolean isLoanPrincipalRepayment(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.loanPrincipalRepayment;
    }

    public static Boolean isProfitDistribution(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.profitDistribution;
    }

    public static Boolean generatesExpenseAllocation(String transactionType) {
        TransactionTypeRule rule = ruleFor(transactionType);
        return rule != null && rule.expenseAllocation;
    }

    public static Set<String> ownerContributionTypes() {
        Set<String> typeNames = new Set<String>();
        for (String typeName : RULES_BY_TYPE.keySet()) {
            if (RULES_BY_TYPE.get(typeName).ownerContribution) {
                typeNames.add(typeName);
            }
        }
        return typeNames;
    }

    private static Map<String, TransactionTypeRule> buildRules() {
        Map<String, TransactionTypeRule> rules = new Map<String, TransactionTypeRule>();
        addRule(rules, 'Down_Payment', 'Inward', true, true, false, false, true, false, false, false);
        addRule(rules, 'Owner_Contribution', 'Inward', true, true, false, false, true, false, false, false);
        addRule(rules, 'Loan_Disbursement', 'Inward', true, false, false, false, false, false, false, false);
        addRule(rules, 'Income_From_Asset', 'Inward', true, false, false, true, false, false, false, false);
        addRule(rules, 'Return', 'Inward', true, false, false, true, false, false, false, false);
        addRule(rules, 'Other_Income', 'Inward', true, false, false, false, false, false, false, false);
        addRule(rules, 'Loan_Repayment', 'Outward', true, false, true, false, false, true, false, false);
        addRule(rules, 'Interest_Payment', 'Outward', true, false, true, false, false, false, false, false);
        addRule(rules, 'Maintenance_Expense', 'Outward', true, false, false, false, false, false, false, true);
        addRule(rules, 'Insurance', 'Outward', true, false, false, false, false, false, false, true);
        addRule(rules, 'Profit_Distribution', 'Outward', true, true, false, false, false, false, true, false);
        addRule(rules, 'Other_Expense', 'Outward', true, false, false, false, false, false, false, true);
        return rules;
    }

    private static void addRule(
        Map<String, TransactionTypeRule> rules,
        String typeName,
        String direction,
        Boolean requiresAsset,
        Boolean requiresOwner,
        Boolean requiresLoan,
        Boolean generatesPayout,
        Boolean ownerContribution,
        Boolean loanPrincipalRepayment,
        Boolean profitDistribution,
        Boolean expenseAllocation
    ) {
        rules.put(
            typeName,
            new TransactionTypeRule(
                typeName,
                direction,
                requiresAsset,
                requiresOwner,
                requiresLoan,
                generatesPayout,
                ownerContribution,
                loanPrincipalRepayment,
                profitDistribution,
                expenseAllocation
            )
        );
    }
}
