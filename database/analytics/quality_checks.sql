-- Read-only evidence. No automatic balance correction. All checks share one SQL snapshot.
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
START TRANSACTION WITH CONSISTENT SNAPSHOT;
SELECT 'LEDGER_MISMATCH' AS issue,a.user_id,a.balance,COALESCE(SUM(t.delta),0) AS expected_balance
FROM culturepick.credit_accounts a LEFT JOIN culturepick.credit_transactions t ON t.user_id=a.user_id
GROUP BY a.user_id,a.balance HAVING a.balance<>COALESCE(SUM(t.delta),0);
-- Validate each recorded balance, not just the final sum.
SELECT 'LEDGER_MISMATCH' AS issue,id,user_id,balance_after,running_balance FROM (
 SELECT id,user_id,balance_after,SUM(delta) OVER(PARTITION BY user_id ORDER BY id ROWS UNBOUNDED PRECEDING) AS running_balance
 FROM culturepick.credit_transactions
) balances WHERE balance_after<>running_balance;
SELECT 'PAYLOAD_MISMATCH' AS issue,r.id,r.total_credit,p.delta,p.id AS purchase_id
FROM culturepick.reservations r LEFT JOIN culturepick.credit_transactions p ON p.reservation_id=r.id AND p.type='PURCHASE'
WHERE p.id IS NULL OR p.user_id<>r.user_id OR p.delta<>-r.total_credit;
SELECT 'PAYLOAD_MISMATCH' AS issue,f.id,f.reversal_of FROM culturepick.credit_transactions f
LEFT JOIN culturepick.credit_transactions p ON p.id=f.reversal_of
WHERE f.type='REFUND' AND (p.id IS NULL OR p.type<>'PURCHASE' OR f.delta<>-p.delta OR f.user_id<>p.user_id OR f.reservation_id<>p.reservation_id);
SELECT 'PAYLOAD_MISMATCH' AS issue,r.id FROM culturepick.reservations r
LEFT JOIN culturepick.credit_transactions f ON f.reservation_id=r.id AND f.type='REFUND'
WHERE (r.status='CANCELLED' AND f.id IS NULL) OR (r.status='CONFIRMED' AND f.id IS NOT NULL);
SELECT 'ORPHAN_REFERENCE' AS issue,v.id FROM culturepick.visit_history v JOIN culturepick.reservations r ON r.id=v.reservation_id
JOIN culturepick.content_sessions s ON s.id=r.session_id WHERE v.content_id<>s.content_id;
-- Delivery state is not proof of Mongo absence: actual Mongo extraction must confirm it.
SELECT event_id,status,attempts,TIMESTAMPDIFF(SECOND,occurred_at,UTC_TIMESTAMP(6)) AS age_seconds
FROM culturepick.event_outbox WHERE status IN ('PENDING','FAILED') ORDER BY occurred_at;
COMMIT;
