-- Indexes are created by Alembic, not by this exercise file.
-- EXPLAIN compares optimizer plans on the same query/data, without destructive DROP INDEX.
USE culturepick;
SHOW INDEX FROM contents;
SHOW INDEX FROM reviews;
SHOW INDEX FROM event_outbox;
EXPLAIN FORMAT=JSON SELECT id,title FROM contents IGNORE INDEX(ix_content_region_start)
 WHERE region_code='SEOUL' AND start_at>='2099-12-01' AND start_at<'2100-01-01';
EXPLAIN FORMAT=JSON SELECT id,title FROM contents FORCE INDEX(ix_content_region_start)
 WHERE region_code='SEOUL' AND start_at>='2099-12-01' AND start_at<'2100-01-01';
EXPLAIN FORMAT=JSON SELECT id,rating FROM reviews WHERE content_id=101 AND deleted_at IS NULL ORDER BY created_at;
EXPLAIN FORMAT=JSON SELECT event_id FROM event_outbox WHERE status='PENDING' AND next_retry_at<=UTC_TIMESTAMP(6) ORDER BY next_retry_at LIMIT 100;
-- Leading-wildcard LIKE cannot be fixed by a normal B-tree. No unmeasured speedup is claimed.
EXPLAIN FORMAT=JSON SELECT id FROM contents WHERE title LIKE '%가상%';
