SET @from_date=COALESCE(@from_date,DATE(UTC_TIMESTAMP()+INTERVAL 9 HOUR));
SET @to_date=COALESCE(@to_date,@from_date);
-- SQL ledger is the only monetary source. Refund is attributed to its own day.
-- Signed net credit may be negative on a refund-only day.
START TRANSACTION;
DELETE FROM culturepick_analytics.daily_content_metrics WHERE business_date BETWEEN @from_date AND @to_date;
INSERT INTO culturepick_analytics.daily_content_metrics
 (business_date,dataset_key,content_id,view_count,bookmark_add_count,reservation_count,cancelled_count,gross_credit,refund_credit,net_credit)
SELECT business_date,dataset_key,content_id,SUM(views),SUM(bookmarks),SUM(purchases),SUM(refunds),SUM(gross),SUM(refund),SUM(gross)-SUM(refund)
FROM (
 SELECT business_date,dataset_key,content_id,SUM(event_type='content_viewed') AS views,
  SUM(event_type='bookmark_added') AS bookmarks,0 AS purchases,0 AS refunds,0 AS gross,0 AS refund
 FROM culturepick_analytics.clean_events
 WHERE business_date BETWEEN @from_date AND @to_date AND content_id IS NOT NULL
 GROUP BY business_date,dataset_key,content_id
 UNION ALL
 SELECT DATE(t.created_at+INTERVAL 9 HOUR),t.dataset_key,s.content_id,0,0,
  SUM(t.type='PURCHASE'),SUM(t.type='REFUND'),SUM(IF(t.type='PURCHASE',-t.delta,0)),SUM(IF(t.type='REFUND',t.delta,0))
 FROM culturepick.credit_transactions t JOIN culturepick.reservations r ON r.id=t.reservation_id
 JOIN culturepick.content_sessions s ON s.id=r.session_id
 WHERE t.created_at>=TIMESTAMP(@from_date)-INTERVAL 9 HOUR
  AND t.created_at<TIMESTAMP(DATE_ADD(@to_date,INTERVAL 1 DAY))-INTERVAL 9 HOUR
  AND t.type IN ('PURCHASE','REFUND')
 GROUP BY DATE(t.created_at+INTERVAL 9 HOUR),t.dataset_key,s.content_id
) facts GROUP BY business_date,dataset_key,content_id;
COMMIT;
