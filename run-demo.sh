#!/bin/bash
set -e

echo "🚀 dbtpl Duplicate Function Fix Demo"
echo "===================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f ".env" ]; then
    export $(cat .env | xargs)
else
    echo -e "${RED}❌ .env file not found. Please copy .env.example to .env and set your credentials.${NC}"
    exit 1
fi

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v mysql &> /dev/null; then
    echo -e "${RED}❌ MySQL not found. Please install MySQL.${NC}"
    exit 1
fi

if ! command -v dbtpl &> /dev/null; then
    echo -e "${RED}❌ dbtpl not found. Please install: go install github.com/xo/dbtpl@latest${NC}"
    exit 1
fi

if [ ! -f "dbtpl-fixed" ]; then
    echo -e "${RED}❌ dbtpl-fixed not found. Please build the fixed version:${NC}"
    echo "   cd /path/to/your/dbtpl/fork"
    echo "   go build -o dbtpl-fixed ."
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites found${NC}"

# Database connection string
DB_DSN="mysql://${DB_USER}:${DB_PASSWORD}@tcp(${DB_HOST}:3306)/${DB_NAME}?parseTime=true"

# Create database
echo -e "${BLUE}Creating demo database...${NC}"
mysql -h${DB_HOST} -u${DB_USER} -p${DB_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};" 2>/dev/null || true

# Apply schema
echo -e "${BLUE}Applying schema...${NC}"
mysql -h${DB_HOST} -u${DB_USER} -p${DB_PASSWORD} ${DB_NAME} < schema.sql

echo -e "${GREEN}✓ Schema applied to database${NC}"

# Clean up previous runs
rm -rf models-before models-after

# Test BEFORE fix (original dbtpl)
echo -e "${BLUE}Testing BEFORE fix (original dbtpl)...${NC}"
mkdir -p models-before

echo "Generating code with original dbtpl..."
if dbtpl schema "${DB_DSN}" -o models-before 2>&1; then
    echo -e "${GREEN}✓ Code generation succeeded${NC}"

    # Check for duplicate functions in generated files
    if ls models-before/*.go &> /dev/null; then
        echo "Checking for duplicate function names..."
        func_count=$(grep -c "func.*ById" models-before/*.go 2>/dev/null || echo "0")
        if [ "$func_count" -gt "1" ]; then
            echo -e "${RED}🐛 DUPLICATE FUNCTIONS DETECTED (this is the bug):${NC}"
            grep -n "func.*ById" models-before/*.go || true

            # Try to compile to show the error
            echo "Attempting to compile (should fail)..."
            if ! go build -o /dev/null ./models-before/... 2>&1; then
                echo -e "${RED}❌ Compilation failed due to duplicate functions${NC}"
            fi
        fi
    fi
else
    echo -e "${RED}❌ Code generation failed${NC}"
fi

# Test AFTER fix (fixed dbtpl)
echo -e "${BLUE}Testing AFTER fix (fixed dbtpl)...${NC}"
mkdir -p models-after

echo "Generating code with FIXED dbtpl..."
if ./dbtpl-fixed schema "${DB_DSN}" -o models-after; then
    echo -e "${GREEN}✅ Code generation succeeded with fixed version!${NC}"

    # Check for unique function names
    if ls models-after/*.go &> /dev/null; then
        echo "Generated functions:"
        grep -n "func.*ById" models-after/*.go || echo "No ById functions found"

        # Verify no duplicates
        func_count=$(grep -c "func.*ById" models-after/*.go 2>/dev/null || echo "0")
        unique_count=$(grep "func.*ById" models-after/*.go 2>/dev/null | sort -u | wc -l || echo "0")

        if [ "$func_count" -eq "$unique_count" ] && [ "$func_count" -gt "0" ]; then
            echo -e "${GREEN}✅ All function names are UNIQUE!${NC}"
        else
            echo -e "${RED}❌ Still found duplicate function names${NC}"
        fi
    fi

    # Try to compile the generated code
    echo "Testing compilation..."
    if go build -o /dev/null ./models-after/... 2>&1; then
        echo -e "${GREEN}✅ Generated code COMPILES successfully!${NC}"
    else
        echo -e "${RED}❌ Generated code failed to compile${NC}"
    fi
else
    echo -e "${RED}❌ Code generation failed unexpectedly${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Demo completed!${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "• Original dbtpl: Generates duplicate functions (compilation error)"
echo "• Fixed dbtpl: Generates unique functions with suffixes (compiles successfully)"
echo "• The fix is backwards compatible and only adds suffixes when conflicts exist"