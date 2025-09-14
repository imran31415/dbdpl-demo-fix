# dbtpl Duplicate Function Fix Demo

Supporting evidence for [dbtpl PR](https://github.com/xo/dbtpl/pull/XXX) that fixes [issue #407](https://github.com/xo/dbtpl/issues/407) - "Prevent generating duplicate function".

## The Problem

When a table has multiple indexes on the same column (e.g., primary key + unique index), the original dbtpl generates **duplicate function names**, causing compilation errors.

## Proof of Fix

This repo contains a minimal demonstration showing:

1. **`schema.sql`** - Schema that triggers the duplicate function bug
2. **`DEMO_RESULTS.md`** - Detailed before/after comparison
3. **`run-demo.sh`** - Script to test both original and fixed versions

## Quick Test

```bash
# Setup
cp .env.example .env
# Edit .env with your MySQL credentials

# Run automated demo
./run-demo.sh
```

**Manual test:**
```bash
# Apply problematic schema
mysql -u root -p demo_db < schema.sql

# Test with original dbtpl (will generate duplicates)
go install github.com/xo/dbtpl@latest
dbtpl schema "mysql://root:password@tcp(localhost:3306)/demo_db?parseTime=true" -o models-before

# Test with fixed version
git clone https://github.com/YOUR_USERNAME/dbtpl.git
cd dbtpl && git checkout test-duplicate-function-generation
go build -o dbtpl-fixed .
./dbtpl-fixed schema "mysql://root:password@tcp(localhost:3306)/demo_db?parseTime=true" -o models-after

# Compare results
go build ./models-before/...  # Will fail with duplicate function error
go build ./models-after/...   # Will compile successfully
```

## Key Results

- **Before**: Generates duplicate `XoTestById` functions → compilation error
- **After**: Generates unique `XoTestByIdPk` and `XoTestByIdUnique` functions → compiles successfully
- **Backwards Compatible**: Single indexes keep original names (no breaking changes)

See `DEMO_RESULTS.md` for detailed comparison.