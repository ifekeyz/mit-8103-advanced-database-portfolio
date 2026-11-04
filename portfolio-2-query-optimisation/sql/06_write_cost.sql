CREATE TEMP TABLE le_no_index (LIKE ledger_entries INCLUDING DEFAULTS);

CREATE TEMP TABLE le_with_index (LIKE ledger_entries INCLUDING DEFAULTS);
CREATE INDEX tmp_le_account_created ON le_with_index (account_id, created_at DESC);
CREATE INDEX tmp_le_large_debits ON le_with_index (created_at)
    INCLUDE (account_id, amount) WHERE direction = 'DEBIT' AND amount >= 4000;

INSERT INTO le_no_index   SELECT * FROM ledger_entries;
INSERT INTO le_with_index SELECT * FROM ledger_entries;

SELECT 'no indexes' AS copy, pg_size_pretty(pg_total_relation_size('le_no_index')) AS total_size
UNION ALL
SELECT 'with indexes', pg_size_pretty(pg_total_relation_size('le_with_index'));

DROP TABLE le_no_index;
DROP TABLE le_with_index;