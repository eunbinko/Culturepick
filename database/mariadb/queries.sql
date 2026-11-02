-- Prepared-statement equivalents: bind every value in the backend, never concatenate input.
USE culturepick;
SET @user_id=COALESCE(@user_id,1), @content_id=COALESCE(@content_id,101);
SET @region=COALESCE(@region,'SEOUL'), @query=COALESCE(@query,'가상');
SET @range_start=COALESCE(@range_start,'2099-12-01 00:00:00'), @range_end=COALESCE(@range_end,'2099-12-31 23:59:59');
-- Known schedule overlap, not full containment. Unknown time is excluded when date-filtered.
SELECT c.id,c.title,c.venue_name,c.price_min,c.price_max,c.is_free,r.average_rating,COALESCE(r.review_count,0) AS review_count
FROM contents c LEFT JOIN (
 SELECT content_id,AVG(rating) AS average_rating,COUNT(*) AS review_count FROM reviews WHERE deleted_at IS NULL GROUP BY content_id
) r ON r.content_id=c.id
WHERE c.status='ACTIVE' AND c.deleted_at IS NULL AND c.region_code=@region
 AND c.start_at<=@range_end AND c.end_at>=@range_start
 AND (c.title LIKE CONCAT('%',@query,'%') OR c.venue_name LIKE CONCAT('%',@query,'%'))
ORDER BY c.start_at,c.id LIMIT 20 OFFSET 0;
-- Known free content only, NULL price is not free.
SELECT id,title FROM contents WHERE status='ACTIVE' AND deleted_at IS NULL AND is_free=1 ORDER BY id;
SELECT c.id,c.title,b.created_at FROM bookmarks b JOIN contents c ON c.id=b.content_id
WHERE b.user_id=@user_id ORDER BY b.created_at DESC,c.id DESC LIMIT 20;
SELECT id,rating,body,version FROM reviews WHERE user_id=@user_id AND deleted_at IS NULL ORDER BY created_at DESC,id DESC;
SELECT r.id,r.status,r.quantity,r.total_credit,s.starts_at,c.title FROM reservations r
JOIN content_sessions s ON s.id=r.session_id JOIN contents c ON c.id=s.content_id
WHERE r.user_id=@user_id ORDER BY r.created_at DESC,r.id DESC LIMIT 20;
SELECT balance FROM credit_accounts WHERE user_id=@user_id;
SELECT id,type,delta,balance_after,reservation_id,created_at FROM credit_transactions
WHERE user_id=@user_id ORDER BY created_at DESC,id DESC LIMIT 20;
-- Dispatcher: single process, due PENDING rows only. SENT follows confirmed Mongo insert/equality.
SELECT event_id,payload_json,attempts FROM event_outbox
WHERE status='PENDING' AND next_retry_at<=UTC_TIMESTAMP(6) ORDER BY next_retry_at,event_id LIMIT 100;
-- Explicit transaction and deterministic lock order. Inspection only: never commit a purchase here.
START TRANSACTION;
SELECT user_id,balance FROM credit_accounts WHERE user_id=@user_id FOR UPDATE;
SELECT id,starts_at,credit_price FROM content_sessions WHERE id=301 FOR UPDATE;
ROLLBACK;
-- Collection UPSERT contract: only source-owned fields, no title-based cross-provider merge.
-- INSERT INTO contents(source,external_id,title,...) VALUES(%s,%s,%s,...)
-- ON DUPLICATE KEY UPDATE title=VALUES(title),collected_at=VALUES(collected_at),...;
