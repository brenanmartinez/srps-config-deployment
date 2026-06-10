# SRPS Export Flag Automation - Usage Guide

**Version**: 1.0  
**Last Updated**: 2026-06-10

---

## Table of Contents

1. [Overview](#overview)
2. [Input Requirements](#input-requirements)
3. [Step-by-Step Instructions](#step-by-step-instructions)
4. [Output Details](#output-details)
5. [Common Use Cases](#common-use-cases)
6. [Troubleshooting](#troubleshooting)

---

## Overview

The Export Flag Automation tool generates SQL scripts that set export flags (`C_EXPORT = 1`) on transaction definitions and their related configuration objects in the SRPS entellitrak system.

**What you provide:**
- A list of transaction definition codes (one per line)

**What you get:**
- A complete SQL script that:
  - Resets all export flags to 0
  - Sets export flags for your specified transactions
  - Automatically includes related objects (fees, rules, letter templates, relationships)

---

## Input Requirements

### Transaction Codes File Format

**Required Format:**
```
transactionDefinition.{codeName}
```

**Valid Example:**
```
transactionDefinition.licensedArchitectInitialApplication
transactionDefinition.licensedEngineerRenewal
transactionDefinition.licensedSurveyorEndorsement
```

**Important Rules:**
- ✅ One transaction code per line
- ✅ Must start with `transactionDefinition.`
- ✅ Code name should match exactly what's in your database
- ✅ Comments (lines starting with `#`) are allowed
- ✅ Blank lines are allowed
- ❌ No spaces around the code
- ❌ No quotation marks
- ❌ No trailing commas or semicolons

### Where to Find Transaction Codes

**Option 1: Query the Database**
```sql
SELECT C_CODE 
FROM T_PSO_TRANSACTION_DEFINITION 
WHERE C_NAME LIKE '%Architect%'
ORDER BY C_CODE;
```

**Option 2: Check Entellitrak Admin UI**
1. Log into Entellitrak Admin
2. Navigate to: **Configuration > Professional Services Online > Transaction Definitions**
3. Note the "Code" column values
4. Prepend each code with `transactionDefinition.`

**Option 3: Use Existing Export Lists**
- Check previous deployment documentation
- Ask your team lead for the standard transaction list

---

## Step-by-Step Instructions

### Step 1: Prepare Your Input File

Create a text file with your transaction codes:

```bash
# Option A: Use a text editor
nano my_transactions.txt

# Option B: Use VS Code
code my_transactions.txt

# Option C: Copy from example
cp examples/sample_transaction_codes.txt my_transactions.txt
```

**Example content:**
```
transactionDefinition.licensedArchitectInitialApplication
transactionDefinition.licensedArchitectRenewal
transactionDefinition.licensedEngineerInitialApplication
```

### Step 2: Run the Generator Script

```bash
./scripts/generate_export_flag_script.sh my_transactions.txt > output/export_flags.sql
```

**What this does:**
- Reads your transaction codes from `my_transactions.txt`
- Generates a complete SQL script
- Saves output to `output/export_flags.sql`

### Step 3: Review the Generated SQL

**IMPORTANT**: Always review the SQL before running it!

```bash
# View the full script
less output/export_flags.sql

# Or open in VS Code
code output/export_flags.sql

# Check how many transactions will be affected
grep "WHERE C_CODE IN" output/export_flags.sql -A 20
```

**Things to verify:**
- Transaction count matches your input
- Transaction codes are correct
- No unexpected codes included
- SQL syntax looks valid

### Step 4: Apply to Target Environment

**Option A: SQL Server Management Studio (SSMS)**
1. Open SSMS
2. Connect to your target database
3. File > Open > Select `export_flags.sql`
4. Review one more time
5. Click Execute (F5)

**Option B: Command Line (sqlcmd)**
```bash
sqlcmd -S your-server.tylertech.com \
       -d ILDFPR_DEV \
       -U your-username \
       -P your-password \
       -i output/export_flags.sql
```

**Option C: Azure Data Studio**
1. Open Azure Data Studio
2. Connect to database
3. Open `export_flags.sql`
4. Click Run

### Step 5: Verify Results

Run this query to confirm the flags were set:

```sql
-- Count transactions with export flag enabled
SELECT COUNT(*) as TransactionsMarkedForExport
FROM T_PSO_TRANSACTION_DEFINITION
WHERE C_EXPORT = 1;

-- List specific transactions marked for export
SELECT C_CODE, C_NAME, C_EXPORT
FROM T_PSO_TRANSACTION_DEFINITION
WHERE C_EXPORT = 1
ORDER BY C_CODE;
```

---

## Output Details

### What Gets Exported

When you mark transaction definitions for export, the script automatically includes related objects:

| Object Type | Table | Selection Criteria |
|-------------|-------|-------------------|
| **Transaction Definitions** | `T_PSO_TRANSACTION_DEFINITION` | Codes you provided in input file |
| **Fee Definitions** | `T_PSO_FEE_DEFINITION` | Fees linked to exported transactions |
| **Revenue Codes** | `T_PSO_REVENUE_CODE` | Revenue codes used by exported fees |
| **Rule Definitions** | `T_PSO_RULE_DEFINITION` | Rules attached to exported transactions |
| **Letter Templates** | `T_PSO_LETTER_TEMPLATE` | Letters configured for exported transactions |
| **Relationship Definitions** | `T_PSO_RELATIONSHIP_DEFINITION` | Relationships in transaction questions |

### SQL Script Structure

The generated SQL script has this structure:

```sql
BEGIN TRANSACTION;

-- 1. Reset all export flags to 0
UPDATE T_PSO_TRANSACTION_DEFINITION SET C_EXPORT = 0;
UPDATE T_PSO_FEE_DEFINITION SET C_EXPORT = 0;
-- ... (other tables)

-- 2. Enable export for specified transactions
UPDATE T_PSO_TRANSACTION_DEFINITION
SET C_EXPORT = 1
WHERE C_CODE IN (
    'transactionDefinition.code1',
    'transactionDefinition.code2',
    ...
);

-- 3. Enable export for related fees
UPDATE T_PSO_FEE_DEFINITION ...

-- 4. Enable export for related revenue codes
UPDATE T_PSO_REVENUE_CODE ...

-- 5. Enable export for related rules
UPDATE T_PSO_RULE_DEFINITION ...

-- 6. Enable export for related letter templates
UPDATE T_PSO_LETTER_TEMPLATE ...

-- 7. Enable export for related relationships
UPDATE T_PSO_RELATIONSHIP_DEFINITION ...

COMMIT TRANSACTION;
```

---

## Common Use Cases

### Use Case 1: New Release Deployment

**Scenario**: You're deploying Q2 2026 release with 15 new transaction types.

**Steps:**
1. Get list of new transaction codes from release notes
2. Create input file with those codes
3. Generate SQL for each environment (DEV, QA, UAT, PROD)
4. Apply in order: DEV → QA → UAT → PROD
5. Export `.eab` bundle after each environment

### Use Case 2: Hotfix for Specific Transactions

**Scenario**: Bug fix needed for 3 architect transactions only.

**Steps:**
1. Create minimal input file with just those 3 codes
2. Generate SQL
3. Apply to target environment
4. Export small focused `.eab` with just those transactions

### Use Case 3: Complete System Export

**Scenario**: Initial setup or disaster recovery - need everything.

**Steps:**
1. Query database for ALL transaction codes:
   ```sql
   SELECT C_CODE FROM T_PSO_TRANSACTION_DEFINITION ORDER BY C_CODE;
   ```
2. Save results to input file
3. Generate comprehensive SQL
4. Apply and export complete configuration

---

## Troubleshooting

### Problem: Script says "Transaction not found"

**Cause**: Transaction code doesn't exist in target database

**Solution**:
1. Verify code spelling (case-sensitive!)
2. Query database to see what codes exist:
   ```sql
   SELECT C_CODE FROM T_PSO_TRANSACTION_DEFINITION 
   WHERE C_CODE LIKE '%yourSearchTerm%';
   ```
3. Check if you're connected to the right environment

### Problem: SQL script is empty or very short

**Cause**: Input file might be in wrong format or empty

**Solution**:
1. Check input file exists: `ls -l my_transactions.txt`
2. Check file has content: `cat my_transactions.txt`
3. Verify format matches `transactionDefinition.codeName`
4. Check for Windows line endings: `dos2unix my_transactions.txt`

### Problem: Export still missing some objects

**Cause**: Some objects might not be linked via standard relationships

**Solution**:
1. Manually verify which objects are missing
2. Check if they're linked differently in your database
3. Manually add UPDATE statements for those objects
4. Report to development team to enhance script

### Problem: Permission denied when running script

**Cause**: Script not executable

**Solution**:
```bash
chmod +x scripts/generate_export_flag_script.sh
```

### Problem: SQL execution fails with syntax error

**Cause**: SQL Server version differences or database dialect

**Solution**:
1. Check SQL Server version compatibility
2. Verify you're not using PostgreSQL syntax on SQL Server
3. Review generated SQL for any malformed statements

---

## Best Practices

### ✅ DO

- **Always review generated SQL** before executing
- **Test in DEV first** before applying to production
- **Keep input files** in version control for repeatability
- **Document your transaction lists** in release notes
- **Back up the database** before running export flag updates
- **Run verification queries** after applying SQL

### ❌ DON'T

- **Don't run in production** without testing in lower environments
- **Don't skip the review step** - always read the SQL
- **Don't commit generated SQL** to git (it's in .gitignore for a reason)
- **Don't edit the generated SQL** by hand (regenerate instead)
- **Don't apply export flags** without coordinating with the team

---

## Next Steps

- See [GITHUB_INTEGRATION_PLAN.md](GITHUB_INTEGRATION_PLAN.md) for future automation via GitHub Actions
- Check [TRANSACTION_CODE_REFERENCE.md](TRANSACTION_CODE_REFERENCE.md) for common transaction codes
- Review the [README.md](../README.md) for project overview

---

**Questions or Issues?**

Contact: Brenan Martinez  
Project: SRPS Config Deployment  
Repository: https://github.com/brenanmartinez/srps-config-deployment
