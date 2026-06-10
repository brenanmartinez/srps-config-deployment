#!/bin/bash

################################################################################
# Validate Transaction Codes
#
# This script validates that transaction codes in an input file match the
# expected format: transactionDefinition.{codeName}
#
# Usage:
#   ./validate_transaction_codes.sh <input_file>
#
# Returns:
#   Exit code 0 if all codes are valid
#   Exit code 1 if any invalid codes found
#
# Author: Brenan Martinez / Claude Code
# Created: 2026-06-10
################################################################################

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    echo ""
    echo "Example:"
    echo "  $0 transaction_codes.txt"
    exit 1
fi

INPUT_FILE="$1"

# Check if file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}✗ Error: Input file '$INPUT_FILE' not found.${NC}"
    exit 1
fi

echo "Validating transaction codes in: $INPUT_FILE"
echo ""

# Read and validate each line
VALID_COUNT=0
INVALID_COUNT=0
BLANK_COUNT=0
COMMENT_COUNT=0
LINE_NUM=0

while IFS= read -r line; do
    LINE_NUM=$((LINE_NUM + 1))

    # Skip blank lines
    if [[ -z "${line// }" ]]; then
        BLANK_COUNT=$((BLANK_COUNT + 1))
        continue
    fi

    # Skip comment lines
    if [[ "$line" =~ ^[[:space:]]*# ]]; then
        COMMENT_COUNT=$((COMMENT_COUNT + 1))
        continue
    fi

    # Validate format: transactionDefinition.{codeName}
    if [[ "$line" =~ ^transactionDefinition\.[a-zA-Z0-9_]+$ ]]; then
        VALID_COUNT=$((VALID_COUNT + 1))
        echo -e "${GREEN}✓${NC} Line $LINE_NUM: $line"
    else
        INVALID_COUNT=$((INVALID_COUNT + 1))
        echo -e "${RED}✗${NC} Line $LINE_NUM: INVALID FORMAT: $line"
        echo -e "   ${YELLOW}Expected format: transactionDefinition.codeName${NC}"
    fi
done < "$INPUT_FILE"

echo ""
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo "Total lines:     $LINE_NUM"
echo "Valid codes:     $VALID_COUNT"
echo "Invalid codes:   $INVALID_COUNT"
echo "Comments:        $COMMENT_COUNT"
echo "Blank lines:     $BLANK_COUNT"
echo ""

if [ $INVALID_COUNT -eq 0 ]; then
    echo -e "${GREEN}✓ All transaction codes are valid!${NC}"
    exit 0
else
    echo -e "${RED}✗ Found $INVALID_COUNT invalid transaction code(s).${NC}"
    echo ""
    echo "Valid format examples:"
    echo "  transactionDefinition.licensedArchitectInitialApplication"
    echo "  transactionDefinition.licensedEngineerRenewal"
    echo ""
    exit 1
fi
