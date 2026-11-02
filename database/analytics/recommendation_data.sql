SET @as_of_date=COALESCE(@as_of_date,DATE(UTC_TIMESTAMP()+INTERVAL 9 HOUR));
-- Proposal: rolling 30-day behavioral score. Explicit and implicit components remain inspectable.
START TRANSACTION;
DELETE FROM culturepick_analytics.user_genre_features WHERE as_of_date=@as_of_date;
INSERT INTO culturepick_analytics.user_genre_features(user_id,genre_id,dataset_key,as_of_date,interest_score,normalization_version)
SELECT e.user_id,cg.genre_id,e.dataset_key,@as_of_date,
 GREATEST(0,SUM(CASE e.event_type WHEN 'content_viewed' THEN 0.1 WHEN 'bookmark_added' THEN 3
  WHEN 'bookmark_removed' THEN -3 WHEN 'review_created' THEN 1 WHEN 'reservation_confirmed' THEN 2
  WHEN 'reservation_cancelled' THEN -2 ELSE 0 END)),1
FROM culturepick_analytics.clean_events e JOIN culturepick.content_genres cg ON cg.content_id=e.content_id
WHERE e.user_id IS NOT NULL AND e.business_date BETWEEN DATE_SUB(@as_of_date,INTERVAL 29 DAY) AND @as_of_date
GROUP BY e.user_id,cg.genre_id,e.dataset_key;
COMMIT;
-- CTR: one click per actual impression opportunity, matched by recommendation ID, actor and item.
-- recommendation_id must be newly generated for each display opportunity.
WITH impressions AS (
 SELECT JSON_UNQUOTE(JSON_EXTRACT(properties_json,'$.recommendation_id')) AS rec,
  COALESCE(CONCAT('u:',user_id),CONCAT('a:',JSON_UNQUOTE(JSON_EXTRACT(properties_json,'$.anonymous_id')))) AS actor,
  content_id,dataset_key,MIN(occurred_at) AS exposed_at
 FROM culturepick_analytics.clean_events WHERE event_type='recommendation_impression' AND business_date=@as_of_date
 GROUP BY rec,actor,content_id,dataset_key
), clicks AS (
 SELECT DISTINCT JSON_UNQUOTE(JSON_EXTRACT(properties_json,'$.recommendation_id')) AS rec,
  COALESCE(CONCAT('u:',user_id),CONCAT('a:',JSON_UNQUOTE(JSON_EXTRACT(properties_json,'$.anonymous_id')))) AS actor,
  content_id,dataset_key,occurred_at
 FROM culturepick_analytics.clean_events WHERE event_type='recommendation_clicked'
), matched AS (
 SELECT i.rec,i.actor,i.content_id,i.dataset_key,MAX(c.rec IS NOT NULL) AS clicked
 FROM impressions i LEFT JOIN clicks c ON c.rec=i.rec AND c.actor=i.actor AND c.content_id=i.content_id
  AND c.dataset_key=i.dataset_key AND c.occurred_at>=i.exposed_at
 WHERE i.rec IS NOT NULL AND i.actor IS NOT NULL AND i.content_id IS NOT NULL
 GROUP BY i.rec,i.actor,i.content_id,i.dataset_key
)
SELECT dataset_key,COUNT(*) AS impressions,SUM(clicked) AS clicked_opportunities,
 SUM(clicked)/NULLIF(COUNT(*),0) AS ctr FROM matched GROUP BY dataset_key;
