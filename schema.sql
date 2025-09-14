-- Demo schema to reproduce duplicate function generation bug
-- This creates a table with both a primary key and unique index on the same column

DROP TABLE IF EXISTS xo_test;
CREATE TABLE xo_test (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL DEFAULT ''
);

-- This creates the duplicate function issue:
-- Both the primary key and this unique index generate functions for the 'id' column
CREATE UNIQUE INDEX xo_test_id_unique ON xo_test (id);