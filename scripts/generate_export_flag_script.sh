#!/bin/bash

################################################################################
# Generate Export Flag Script
#
# This script generates a SQL script to set export flags for transaction
# definitions and all their related configurations (fees, revenue codes,
# rules, letter templates, and relationship definitions).
#
# Usage:
#   ./generate_export_flag_script.sh <input_file> <output_file>
#   cat transaction_codes.txt | ./generate_export_flag_script.sh - output.sql
#
# Input Format:
#   One transaction definition code per line, e.g.:
#   transactionDefinition.licensedCemeteryAuthorityRenewalApplication
#   transactionDefinition.licensedCemeteryManagerRenewalApplication
#
# Output:
#   SQL script following ILDFPR export flag pattern
#
# Author: Brenan Martinez / Claude Code
# Created: 2026-05-29
################################################################################

set -e  # Exit on error

# Check arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <input_file> [output_file]"
    echo ""
    echo "Examples:"
    echo "  $0 transaction_codes.txt"
    echo "  $0 transaction_codes.txt custom_export_script.sql"
    echo "  cat codes.txt | $0 -"
    echo ""
    echo "Input file should contain one transaction definition code per line."
    echo "If output file is not specified, defaults to 'transaction_export_flags_YYYYMMDD_HHMMSS.sql'"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="${2:-transaction_export_flags_$(date +%Y%m%d_%H%M%S).sql}"

# Read input from file or stdin
if [ "$INPUT_FILE" = "-" ]; then
    echo "Reading transaction codes from stdin..."
    CODES=$(cat)
else
    if [ ! -f "$INPUT_FILE" ]; then
        echo "Error: Input file '$INPUT_FILE' not found."
        exit 1
    fi
    echo "Reading transaction codes from: $INPUT_FILE"
    CODES=$(cat "$INPUT_FILE")
fi

# Remove duplicates, comments, blank lines, and sort
echo "Processing transaction codes..."
UNIQUE_CODES=$(echo "$CODES" | grep -v '^[[:space:]]*$' | grep -v '^[[:space:]]*#' | sort | uniq)
TOTAL_COUNT=$(echo "$UNIQUE_CODES" | wc -l)

echo "Found $TOTAL_COUNT unique transaction definitions"

# Generate SQL code list with proper formatting
SQL_CODE_LIST=""
FIRST=true
while IFS= read -r code; do
    # Skip empty lines
    [ -z "$code" ] && continue

    if [ "$FIRST" = true ]; then
        SQL_CODE_LIST="    '$code'"
        FIRST=false
    else
        SQL_CODE_LIST="${SQL_CODE_LIST},\n    '$code'"
    fi
done <<< "$UNIQUE_CODES"

# Generate the SQL script
echo "Generating SQL script: $OUTPUT_FILE"

cat > "$OUTPUT_FILE" << 'EOFHEADER'
BEGIN TRANSACTION;

-- Reset all export flags to 0
UPDATE T_PSO_TRANSACTION_DEFINITION
SET C_EXPORT = 0;

UPDATE T_PSO_FEE_DEFINITION
SET C_EXPORT = 0;

UPDATE T_PSO_REVENUE_CODE
SET C_EXPORT = 0;

UPDATE T_PSO_RULE_DEFINITION
SET C_EXPORT = 0;

UPDATE T_PSO_LETTER_TEMPLATE
SET C_EXPORT = 0;

UPDATE T_PSO_RELATIONSHIP_DEFINITION
SET C_EXPORT = 0;

EOFHEADER

# Add transaction definitions section with dynamic count and codes
cat >> "$OUTPUT_FILE" << EOFCODES
-- Enable export flag for selected transaction definitions ($TOTAL_COUNT unique)
UPDATE T_PSO_TRANSACTION_DEFINITION
SET C_EXPORT = 1
WHERE C_CODE IN (
$(echo -e "$SQL_CODE_LIST")
);

EOFCODES

# Add the rest of the script
cat >> "$OUTPUT_FILE" << 'EOFFOOTER'
-- Enable export flag for associated fee definitions (direct association)
UPDATE fd
SET fd.C_EXPORT = 1
FROM T_PSO_FEE_DEFINITION fd
INNER JOIN M_PSO_FEE_DEFINITION mfd ON fd.ID = mfd.C_FEE_DEFINITION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mfd.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for associated fee definitions (via credential setup)
UPDATE fd
SET fd.C_EXPORT = 1
FROM T_PSO_FEE_DEFINITION fd
INNER JOIN M_ASSOCIATION ma ON fd.ID = ma.ID_OWNER
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON ma.C_ASSOCIATION = cs.ID
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtca ON cs.ID = mtca.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtca.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for revenue codes (direct association)
UPDATE rc
SET rc.C_EXPORT = 1
FROM T_PSO_REVENUE_CODE rc
INNER JOIN T_PSO_FEE_DEFINITION fd ON rc.ID = fd.C_REVENUE_CODE
INNER JOIN M_PSO_FEE_DEFINITION mfd ON fd.ID = mfd.C_FEE_DEFINITION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mfd.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for revenue codes (via credential setup)
UPDATE rc
SET rc.C_EXPORT = 1
FROM T_PSO_REVENUE_CODE rc
INNER JOIN T_PSO_FEE_DEFINITION fd ON rc.ID = fd.C_REVENUE_CODE
INNER JOIN M_ASSOCIATION ma ON fd.ID = ma.ID_OWNER
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON ma.C_ASSOCIATION = cs.ID
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtca ON cs.ID = mtca.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtca.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (transaction-level rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN M_TRANS_RULE mtr ON rd.ID = mtr.C_RULE
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtr.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (section-level rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN M_TRANS_SECTION_RULE mtsr ON rd.ID = mtsr.C_RULE
INNER JOIN T_PSO_TRANSACTION_SECTION ts ON mtsr.ID_OWNER = ts.ID
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON ts.ID_PARENT = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (question-level rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN M_TRANS_QUESTION_RULE mtqr ON rd.ID = mtqr.C_RULE
INNER JOIN T_PSO_TRANSACTION_QUESTION tq ON mtqr.ID_OWNER = tq.ID
INNER JOIN T_PSO_TRANSACTION_SECTION ts ON tq.ID_PARENT = ts.ID
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON ts.ID_PARENT = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (checklist-level rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN M_TRANS_CHECKLIST_RULE mtcr ON rd.ID = mtcr.C_RULE
INNER JOIN T_PSO_TRANSACTION_CHECKLIST tc ON mtcr.ID_OWNER = tc.ID
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON tc.ID_PARENT = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (checklist item-level rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN M_TRANS_CHECKLIST_ITEM_RULE mtcir ON rd.ID = mtcir.C_RULE
INNER JOIN T_PSO_TRANSACTION_CHECKLST_ITM tci ON mtcir.ID_OWNER = tci.ID
INNER JOIN T_PSO_TRANSACTION_CHECKLIST tc ON tci.ID_PARENT = tc.ID
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON tc.ID_PARENT = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (transaction availability rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN T_PAO_TRANS_AVAILABILITY_RULE tar ON rd.ID = tar.C_RULE_DEFINITION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON tar.C_TRANSACTION_DEFINITION = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for rule definitions (credential number key scheme)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON rd.ID = cs.C_CREDENTIAL_NUMBER_KEY_SCHEME
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtcs ON cs.ID = mtcs.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtcs.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1
AND cs.C_CREDENTIAL_NUMBER_KEY_SCHEME IS NOT NULL;

-- Enable export flag for rule definitions (initial expiration policy)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON rd.ID = cs.C_EXPIRATION_POLICY_INITIAL
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtcs ON cs.ID = mtcs.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtcs.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1
AND cs.C_EXPIRATION_POLICY_INITIAL IS NOT NULL;

-- Enable export flag for rule definitions (standard expiration policy)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON rd.ID = cs.C_EXPIRATION_POLICY_STANDARD
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtcs ON cs.ID = mtcs.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtcs.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1
AND cs.C_EXPIRATION_POLICY_STANDARD IS NOT NULL;

-- Enable export flag for rule definitions (credential status rules)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RULE_DEFINITION rd
INNER JOIN T_PSO_CREDENTIAL_STATUS_RULES csr ON rd.C_CODE = csr.C_RULE
WHERE csr.C_EXPORT = 1;

-- Enable export flag for letter templates (via credential setup template)
UPDATE lt
SET lt.C_EXPORT = 1
FROM T_PSO_LETTER_TEMPLATE lt
INNER JOIN M_CRED_SETUP_TMPL_LETTER_TMPL mcstl ON lt.C_CODE = mcstl.C_LETTER_TEMPLATES
INNER JOIN T_PSO_CREDENTIAL_SETUP_TEMPL cst ON mcstl.ID_OWNER = cst.ID
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON cst.ID_PARENT = cs.ID
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtca ON cs.ID = mtca.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtca.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for letter templates (via board)
UPDATE lt
SET lt.C_EXPORT = 1
FROM T_PSO_LETTER_TEMPLATE lt
INNER JOIN M_BOARD_LETTER_TEMPLATES mblt ON lt.ID = mblt.C_LETTER_TEMPLATES
INNER JOIN T_PSO_BOARD b ON mblt.ID_OWNER = b.ID
INNER JOIN T_PSO_CREDENTIAL_SETUP cs ON cs.ID_PARENT = b.ID
INNER JOIN M_TRANS_CREDENTIAL_ASSOC mtca ON cs.ID = mtca.C_CREDENTIAL_ASSOCIATION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON mtca.ID_OWNER = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for relationship definitions (via transaction questions)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RELATIONSHIP_DEFINITION rd
INNER JOIN M_RELATIONSHIP_DEFN_MULTIPLE mrdm ON rd.C_CODE = mrdm.C_RELATIONSHIP_DEFN_MULTIPLE
INNER JOIN T_PSO_TRANSACTION_QUESTION tq ON mrdm.ID_OWNER = tq.ID
INNER JOIN T_PSO_TRANSACTION_SECTION ts ON tq.ID_PARENT = ts.ID
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON ts.ID_PARENT = td.ID
WHERE td.C_EXPORT = 1;

-- Enable export flag for relationship definitions (via transaction sections)
UPDATE rd
SET rd.C_EXPORT = 1
FROM T_PSO_RELATIONSHIP_DEFINITION rd
INNER JOIN T_PSO_TRANSACTION_SECTION ts ON rd.C_CODE = ts.C_RELATIONSHIP_DEFINITION
INNER JOIN T_PSO_TRANSACTION_DEFINITION td ON ts.ID_PARENT = td.ID
WHERE td.C_EXPORT = 1
AND ts.C_RELATIONSHIP_DEFINITION IS NOT NULL;

COMMIT TRANSACTION;
EOFFOOTER

echo ""
echo "✓ Successfully generated SQL script:"
echo "  Input:  $TOTAL_COUNT unique transaction definitions"
echo "  Output: $OUTPUT_FILE"
echo ""
echo "You can now run this SQL script against your ILDFPR database to set export flags."
echo ""
