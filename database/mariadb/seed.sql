-- Development only, on a freshly migrated DB. All identities and content are synthetic.
-- Reapplying does not reset balances, change purchases, or manufacture new operations.
USE culturepick;
SET time_zone='+00:00';
START TRANSACTION;
INSERT INTO users(id,email,password_hash,nickname,dataset_key,created_at) VALUES
 (1,'demo1@example.invalid','!disabled-synthetic-account','문화 탐험가','demo-20261102-01','2026-11-02 00:00:00'),
 (2,'demo2@example.invalid','!disabled-synthetic-account','전시 산책자','demo-20261102-01','2026-11-02 00:00:01')
ON DUPLICATE KEY UPDATE id=id;
INSERT INTO genres(id,code,name) VALUES (1,'EXHIBITION','전시'),(2,'MUSIC','음악'),(3,'THEATER','연극')
ON DUPLICATE KEY UPDATE id=id;
INSERT INTO user_preferences(user_id,region_code,min_price,max_price,lifestyle_type) VALUES
 (1,'SEOUL',0,30000,'ANY'),(2,'SEOUL',0,0,'RELAXED') ON DUPLICATE KEY UPDATE user_id=user_id;
INSERT INTO user_preference_genres(user_id,genre_id) VALUES(1,1),(1,2),(2,1) ON DUPLICATE KEY UPDATE user_id=user_id;
INSERT INTO contents(id,source,external_id,title,region_code,venue_name,start_at,end_at,price_min,price_max,is_free,description) VALUES
 (101,'synthetic','exhibition-001','도시의 빛: 가상 전시','SEOUL','가상 문화관','2099-12-01 00:00:00','2099-12-31 12:00:00',10000,10000,0,'실습용 합성 콘텐츠입니다.'),
 (102,'synthetic','music-001','정오의 음악: 가상 공연','SEOUL','가상 광장','2099-12-01 03:00:00','2099-12-01 05:00:00',0,0,1,'무료 크레딧 예매 검증용 합성 콘텐츠입니다.'),
 (103,'synthetic','theater-unknown','일정 미정: 가상 연극',NULL,NULL,NULL,NULL,NULL,NULL,NULL,'가격·장소·시간 미제공을 무료로 처리하지 않습니다.')
ON DUPLICATE KEY UPDATE id=id;
INSERT INTO content_genres(content_id,genre_id) VALUES(101,1),(102,2),(103,3) ON DUPLICATE KEY UPDATE content_id=content_id;
INSERT INTO content_sessions(id,content_id,starts_at,credit_price) VALUES
 (301,101,'2099-12-01 01:00:00',10000),(302,102,'2099-12-01 03:00:00',0) ON DUPLICATE KEY UPDATE id=id;
INSERT INTO bookmarks(user_id,content_id,created_at) VALUES(1,101,'2026-11-02 00:03:00') ON DUPLICATE KEY UPDATE user_id=user_id;
INSERT INTO reviews(id,user_id,content_id,rating,body) VALUES(401,1,101,5,'실습용 가상 전시 리뷰입니다.') ON DUPLICATE KEY UPDATE id=id;
INSERT INTO reservations(id,user_id,session_id,quantity,unit_credit,total_credit,status,version,dataset_key,created_at,cancelled_at) VALUES
 (501,1,301,2,10000,20000,'CANCELLED',2,'demo-20261102-01','2026-11-02 00:05:00','2026-11-02 00:06:00'),
 (502,2,302,1,0,0,'CONFIRMED',1,'demo-20261102-01','2026-11-02 00:07:00',NULL)
ON DUPLICATE KEY UPDATE id=id;
INSERT INTO credit_accounts(user_id,balance) VALUES(1,100000),(2,100000) ON DUPLICATE KEY UPDATE user_id=user_id;
INSERT INTO credit_transactions(id,user_id,reservation_id,type,delta,balance_after,reversal_of,operation_id,dataset_key,created_at) VALUES
 (1,1,NULL,'GRANT',100000,100000,NULL,'signup:1','demo-20261102-01','2026-11-02 00:00:00'),
 (2,1,501,'PURCHASE',-20000,80000,NULL,'reservation:501:confirmed','demo-20261102-01','2026-11-02 00:05:00'),
 (3,1,501,'REFUND',20000,100000,2,'reservation:501:cancelled','demo-20261102-01','2026-11-02 00:06:00'),
 (4,2,NULL,'GRANT',100000,100000,NULL,'signup:2','demo-20261102-01','2026-11-02 00:00:01'),
 (5,2,502,'PURCHASE',0,100000,NULL,'reservation:502:confirmed','demo-20261102-01','2026-11-02 00:07:00')
ON DUPLICATE KEY UPDATE id=id;

INSERT INTO event_outbox(event_id,event_type,aggregate_type,aggregate_id,aggregate_version,payload_json,occurred_at,request_id,operation_id)
SELECT CONCAT('00000000-0000-4000-8000-',LPAD(t.id,12,'0')),
 CASE t.type WHEN 'GRANT' THEN 'user_registered' WHEN 'PURCHASE' THEN 'reservation_confirmed' ELSE 'reservation_cancelled' END,
 IF(t.type='GRANT','user','reservation'), CAST(COALESCE(t.reservation_id,t.user_id) AS CHAR),IF(t.type='REFUND',2,1),
 JSON_OBJECT(
  'event_id',CONCAT('00000000-0000-4000-8000-',LPAD(t.id,12,'0')),'schema_version',1,
  'event_type',CASE t.type WHEN 'GRANT' THEN 'user_registered' WHEN 'PURCHASE' THEN 'reservation_confirmed' ELSE 'reservation_cancelled' END,
  'event_source','server','occurred_at',DATE_FORMAT(t.created_at,'%Y-%m-%dT%H:%i:%s.%fZ'),
  'request_id',CONCAT('seed-request-',t.id),'operation_id',t.operation_id,'user_id',CAST(t.user_id AS CHAR),
  'anonymous_id',NULL,'session_id','synthetic-browser-session','content_id',CAST(s.content_id AS CHAR),
  'aggregate_type',IF(t.type='GRANT','user','reservation'),'aggregate_id',CAST(COALESCE(t.reservation_id,t.user_id) AS CHAR),
  'aggregate_version',IF(t.type='REFUND',2,1),'is_test',JSON_EXTRACT('true','$'),'test_run_id',t.dataset_key,
  'properties',IF(t.type='GRANT',JSON_OBJECT('granted_credit',t.delta),
    JSON_OBJECT('reservation_id',CAST(t.reservation_id AS CHAR),'content_session_id',CAST(r.session_id AS CHAR),
     'quantity',r.quantity,'unit_credit',r.unit_credit,'total_credit',r.total_credit))),
 t.created_at,CONCAT('seed-request-',t.id),t.operation_id
FROM credit_transactions t LEFT JOIN reservations r ON r.id=t.reservation_id
LEFT JOIN content_sessions s ON s.id=r.session_id WHERE t.id BETWEEN 1 AND 5 AND t.dataset_key='demo-20261102-01'
ON DUPLICATE KEY UPDATE event_id=VALUES(event_id);

INSERT INTO culturepick_analytics.etl_runs(run_id,window_start,window_end,status,source_counts,input_count,output_count,complete_sources,finished_at)
VALUES('10000000-0000-4000-8000-000000000001','2026-11-02 00:00:00','2026-11-02 00:08:00','PARTIAL',
 JSON_OBJECT('seed',5),5,5,JSON_OBJECT('sql',true,'mongo',false,'loki',false),'2026-11-02 00:08:00')
ON DUPLICATE KEY UPDATE run_id=run_id;
-- Synthetic clean rows are for SQL examples, not evidence of completed Mongo/Loki reconciliation.
INSERT INTO culturepick_analytics.clean_events(event_id,event_type,occurred_at,business_date,user_id,content_id,operation_id,source,is_test,test_run_id,dataset_key,properties_json,normalization_version,run_id)
SELECT event_id,event_type,occurred_at,DATE(occurred_at+INTERVAL 9 HOUR),
 CAST(JSON_UNQUOTE(JSON_EXTRACT(payload_json,'$.user_id')) AS SIGNED),
 CAST(NULLIF(JSON_UNQUOTE(JSON_EXTRACT(payload_json,'$.content_id')),'null') AS SIGNED),
 operation_id,'server',1,'demo-20261102-01','demo-20261102-01',JSON_EXTRACT(payload_json,'$.properties'),1,
 '10000000-0000-4000-8000-000000000001'
FROM event_outbox WHERE request_id LIKE 'seed-request-%'
ON DUPLICATE KEY UPDATE event_id=VALUES(event_id);
COMMIT;
