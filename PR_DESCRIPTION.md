# Fix duplicate function generation when indexes target same columns

## Problem

When a table has multiple indexes targeting the same column(s), dbtpl generates duplicate function names, causing Go compilation errors.

**Specific scenario**: Tables with both primary keys and unique indexes on the same column generate identical function names:

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL
);

-- This creates duplicate function generation:
CREATE UNIQUE INDEX users_id_unique ON users (id);
```

**Result**: Two functions with identical signatures:
```go
func UserById(ctx context.Context, db DB, id int) (*User, error) { ... }  // from PK
func UserById(ctx context.Context, db DB, id int) (*User, error) { ... }  // from unique index - DUPLICATE!
```

**Error**: `UserById redeclared in this block`

## Solution

This PR implements backwards-compatible duplicate detection and resolution:

1. **Conflict Detection**: Analyze all indexes for a table to identify naming conflicts
2. **Smart Suffixes**: Add type-specific suffixes only to conflicting indexes (keeping first/primary unchanged):
   - Primary keys keep original names (backwards compatible)
   - `_unique` for conflicting unique indexes
   - `_idx` for conflicting regular indexes
3. **True Backwards Compatibility**: Existing function names remain unchanged

## Results

**Before (broken)**:
```go
func XoTestById(...) { ... }  // from primary key
func XoTestById(...) { ... }  // from unique index - DUPLICATE!
```

**After (fixed)**:
```go
func XoTestById(...) { ... }       // from primary key (unchanged - backwards compatible)
func XoTestByIdUnique(...) { ... } // from unique index (suffix added to resolve conflict)
```

**Backwards Compatible**:
```go
// Single indexes maintain original names - no breaking changes
func UserByEmail(...) { ... }  // still generates same name
```

## Implementation

**Test-Driven Development Approach:**

1. **Added failing test first** (`TestIndexFuncNameDuplicates`):
   - Created test cases that reproduce the duplicate function bug
   - Test initially **failed** as expected, exposing the issue
   - Added backwards compatibility tests (`TestBackwardsCompatibility`)

2. **Implemented the fix**:
   - Modified `indexFuncName()` to generate base names without automatic suffixes
   - Added `assignUniqueIndexFuncNames()` for conflict-aware name assignment with priority ordering
   - Primary keys get priority to keep original names (backwards compatible)
   - Updated index processing pipeline to use two-pass approach

3. **Verified fix works**:
   - All tests now **pass**, confirming the fix resolves duplicate generation
   - Backwards compatibility tests ensure no breaking changes
   - Generated code compiles successfully without duplicate function errors

## Demo

Live demonstration available at: https://github.com/imran31415/dbdpl-demo-fix

## Testing

- ✅ Unit tests cover duplicate detection and resolution
- ✅ Backwards compatibility tests ensure no breaking changes
- ✅ Integration tests verify generated code compiles successfully
- ✅ Demo repository provides real-world validation

Fixes #407