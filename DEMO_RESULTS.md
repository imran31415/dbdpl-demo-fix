# Demo Results: dbtpl Duplicate Function Fix

This document shows the results of our fix for GitHub issue #407.

## The Test Schema

```sql
CREATE TABLE xo_test (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL DEFAULT ''
);

-- This creates the duplicate function issue:
CREATE UNIQUE INDEX xo_test_id_unique ON xo_test (id);
```

## Before Fix (Original dbtpl)

When running the original dbtpl on this schema, it would generate:

```go
// ❌ DUPLICATE FUNCTION - CAUSES COMPILATION ERROR
// XoTestById retrieves a row from 'public.xo_test' as a XoTest.
// Generated from index 'xo_test_pkey'.
func XoTestById(ctx context.Context, db DB, id int) (*XoTest, error) {
    // query
    const sqlstr = `SELECT ` +
        `id, name ` +
        `FROM public.xo_test ` +
        `WHERE id = $1`
    // run
    logf(sqlstr, id)
    xo := XoTest{
        _exists: true,
    }
    if err := db.QueryRowContext(ctx, sqlstr, id).Scan(&xo.ID, &xo.Name); err != nil {
        return nil, logerror(err)
    }
    return &xo, nil
}

// ❌ DUPLICATE FUNCTION - SAME NAME!
// XoTestById retrieves a row from 'public.xo_test' as a XoTest.
// Generated from index 'xo_test_id_unique'.
func XoTestById(ctx context.Context, db DB, id int) (*XoTest, error) {  // <-- DUPLICATE!
    // Same implementation...
}
```

**Result**: `XoTestById redeclared in this block` - compilation fails!

## After Fix (Our Solution)

Our backwards-compatible fix generates:

```go
// ✅ BACKWARDS COMPATIBLE - PRIMARY KEY KEEPS ORIGINAL NAME!
// XoTestById retrieves a row from 'public.xo_test' as a XoTest.
// Generated from index 'xo_test_pkey'.
func XoTestById(ctx context.Context, db DB, id int) (*XoTest, error) {
    // query
    const sqlstr = `SELECT ` +
        `id, name ` +
        `FROM public.xo_test ` +
        `WHERE id = $1`
    // run
    logf(sqlstr, id)
    xo := XoTest{
        _exists: true,
    }
    if err := db.QueryRowContext(ctx, sqlstr, id).Scan(&xo.ID, &xo.Name); err != nil {
        return nil, logerror(err)
    }
    return &xo, nil
}

// ✅ CONFLICTING INDEX GETS SUFFIX
// XoTestByIdUnique retrieves a row from 'public.xo_test' as a XoTest.
// Generated from index 'xo_test_id_unique'.
func XoTestByIdUnique(ctx context.Context, db DB, id int) (*XoTest, error) {
    // Same implementation with unique name to resolve conflict
}
```

**Result**: ✅ Code compiles successfully! No more duplicate function names!

## Backwards Compatibility

For tables without conflicts, function names remain unchanged:

```go
// Single unique index - NO SUFFIX ADDED (backwards compatible)
func UserByEmail(ctx context.Context, db DB, email string) (*User, error) { ... }

// Single primary key - NO SUFFIX ADDED (backwards compatible)
func PostById(ctx context.Context, db DB, id int) (*Post, error) { ... }
```

## Test Results Summary

| Scenario | Before Fix | After Fix | Status |
|----------|------------|-----------|---------|
| Single PK | ✅ `PostById` | ✅ `PostById` | Backwards Compatible |
| Single Unique | ✅ `UserByEmail` | ✅ `UserByEmail` | Backwards Compatible |
| PK + Unique (same col) | ❌ Duplicate `XoTestById` | ✅ `XoTestById`, `XoTestByIdUnique` | Fixed & Backwards Compatible |
| Multiple Unique (same col) | ❌ Duplicates | ✅ First keeps name, rest get suffixes | Fixed & Backwards Compatible |

## How to Test This Demo

1. **Prerequisites**:
   ```bash
   createdb demo_db
   createdb demo_db_fixed
   go install github.com/xo/dbtpl@latest  # Original version
   ```

2. **Run comparison**:
   ```bash
   cd demo
   ./run-demo.sh
   ```

3. **Manual verification**:
   ```bash
   # Test original (fails)
   dbtpl schema postgres://localhost/demo_db -o before-models

   # Test fixed version (succeeds)
   ./dbtpl-fixed schema postgres://localhost/demo_db_fixed -o after-models
   go build ./after-models/...  # Should compile successfully
   ```

## Key Benefits

1. ✅ **Fixes GitHub issue #407** - No more duplicate function names
2. ✅ **Backwards compatible** - Existing code continues to work
3. ✅ **Smart conflict resolution** - Only adds suffixes when necessary
4. ✅ **Comprehensive test coverage** - Prevents regressions
5. ✅ **Clear naming convention** - `_pk` for primary keys, `_unique` for unique indexes