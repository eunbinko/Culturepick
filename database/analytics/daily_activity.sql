-- Run with one analytics writer. Set dates explicitly when recomputing late arrivals.
SET @from_date=COALESCE(@from_date,DATE(UTC_TIMESTAMP()+INTERVAL 9 HOUR));
SET @to_date=COALESCE(@to_date,@from_date);
START TRANSACTION;
DELETE FROM culturepick_analytics.daily_activity_metrics WHERE business_date BETWEEN @from_date AND @to_date;
INSERT INTO culturepick_analytics.daily_activity_metrics(business_date,dataset_key,event_type,event_count,user_count)
SELECT business_date,dataset_key,event_type,COUNT(*),COUNT(DISTINCT user_id)
FROM culturepick_analytics.clean_events WHERE business_date BETWEEN @from_date AND @to_date
GROUP BY business_date,dataset_key,event_type;
COMMIT;
