# 데이터 사전

Alembic `0001_initial`을 적용한 실제 INFORMATION_SCHEMA에서 생성했습니다.
`python scripts/data_dictionary.py`로 재생성합니다. 비밀번호와 실제 사용자 데이터는 조회하지 않습니다.

공통: ID는 BIGINT, 크레딧은 정수, DATETIME(6)은 UTC입니다. API 이벤트의 참조 ID는 문자열입니다.
NULL은 미제공/미확정을 뜻하며 무료(0)와 구별합니다. FK는 기본 RESTRICT로 이력 연쇄 삭제를 막습니다.

## culturepick.api_idempotency

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| user_id | bigint(20) | NO | None | PRI  |
| operation | varchar(64) | NO | None | PRI  |
| key | varchar(128) | NO | None | PRI  |
| request_hash | char(64) | NO | None |   |
| response_json | longtext | YES | NULL |   |
| completed_at | datetime(6) | YES | NULL |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |

제약·인덱스:

```sql
PRIMARY KEY (`user_id`,`operation`,`key`)
CONSTRAINT `fk_idempotency_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
CONSTRAINT `ck_idempotency_hash` CHECK (`request_hash` regexp '^[0-9a-f]{64}$')
CONSTRAINT `ck_idempotency_response` CHECK (`completed_at` is null and `response_json` is null or `completed_at` is not null and `response_json` is not null)
```

## culturepick.auth_sessions

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| user_id | bigint(20) | NO | None | MUL  |
| token_hash | char(64) | NO | None | UNI  |
| expires_at | datetime(6) | NO | None |   |
| revoked_at | datetime(6) | YES | NULL |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_auth_token` (`token_hash`)
KEY `ix_auth_user_expiry` (`user_id`,`expires_at`)
CONSTRAINT `fk_auth_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
CONSTRAINT `ck_auth_token` CHECK (`token_hash` regexp '^[0-9a-f]{64}$')
```

## culturepick.bookmarks

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| user_id | bigint(20) | NO | None | PRI  |
| content_id | bigint(20) | NO | None | PRI  |
| created_at | datetime(6) | NO | current_timestamp(6) |   |

제약·인덱스:

```sql
PRIMARY KEY (`user_id`,`content_id`)
KEY `ix_bookmark_content` (`content_id`)
CONSTRAINT `fk_bookmark_content` FOREIGN KEY (`content_id`) REFERENCES `contents` (`id`)
CONSTRAINT `fk_bookmark_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
```

## culturepick.collection_runs

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| source | varchar(64) | NO | None |   |
| started_at | datetime(6) | NO | current_timestamp(6) |   |
| finished_at | datetime(6) | YES | NULL |   |
| status | varchar(16) | NO | 'RUNNING' |   |
| read_count | bigint(20) | NO | 0 |   |
| insert_count | bigint(20) | NO | 0 |   |
| update_count | bigint(20) | NO | 0 |   |
| reject_count | bigint(20) | NO | 0 |   |
| error_code | varchar(64) | YES | NULL |   |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
CONSTRAINT `ck_collection_status` CHECK (`status` in ('RUNNING','SUCCEEDED','FAILED','PARTIAL'))
CONSTRAINT `ck_collection_counts` CHECK (`read_count` >= 0 and `insert_count` >= 0 and `update_count` >= 0 and `reject_count` >= 0)
```

## culturepick.contents

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| source | varchar(64) | NO | None | MUL  |
| external_id | varchar(191) | NO | None |   |
| title | varchar(255) | NO | None |   |
| region_code | varchar(32) | YES | NULL | MUL  |
| venue_name | varchar(255) | YES | NULL |   |
| address | varchar(500) | YES | NULL |   |
| start_at | datetime(6) | YES | NULL |   |
| end_at | datetime(6) | YES | NULL |   |
| price_min | bigint(20) | YES | NULL |   |
| price_max | bigint(20) | YES | NULL |   |
| is_free | tinyint(1) | YES | NULL |   |
| image_url | varchar(2048) | YES | NULL |   |
| description | text | YES | NULL |   |
| source_url | varchar(2048) | YES | NULL |   |
| source_updated_at | datetime(6) | YES | NULL |   |
| collected_at | datetime(6) | NO | current_timestamp(6) |   |
| status | varchar(16) | NO | 'ACTIVE' |   |
| deleted_at | datetime(6) | YES | NULL |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_content_source` (`source`,`external_id`)
KEY `ix_content_region_start` (`region_code`,`start_at`)
CONSTRAINT `ck_content_dates` CHECK (`start_at` is null or `end_at` is null or `start_at` <= `end_at`)
CONSTRAINT `ck_content_prices` CHECK ((`price_min` is null or `price_min` >= 0) and (`price_max` is null or `price_max` >= 0) and (`price_min` is null or `price_max` is null or `price_min` <= `price_max`))
CONSTRAINT `ck_content_free` CHECK (`is_free` is null or `is_free` = 0 or `is_free` = 1 and `price_min` is not null and `price_max` is not null and `price_min` = 0 and `price_max` = 0)
CONSTRAINT `ck_content_status` CHECK (`status` in ('ACTIVE','INACTIVE'))
```

## culturepick.content_genres

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| content_id | bigint(20) | NO | None | PRI  |
| genre_id | bigint(20) | NO | None | PRI  |

제약·인덱스:

```sql
PRIMARY KEY (`content_id`,`genre_id`)
KEY `ix_cg_genre_content` (`genre_id`,`content_id`)
CONSTRAINT `fk_cg_content` FOREIGN KEY (`content_id`) REFERENCES `contents` (`id`)
CONSTRAINT `fk_cg_genre` FOREIGN KEY (`genre_id`) REFERENCES `genres` (`id`)
```

## culturepick.content_sessions

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| content_id | bigint(20) | NO | None | MUL  |
| starts_at | datetime(6) | NO | None |   |
| credit_price | bigint(20) | NO | None |   |
| is_simulated | tinyint(1) | NO | 1 |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
KEY `ix_session_content_start` (`content_id`,`starts_at`)
CONSTRAINT `fk_session_content` FOREIGN KEY (`content_id`) REFERENCES `contents` (`id`)
CONSTRAINT `ck_session_price` CHECK (`credit_price` >= 0)
CONSTRAINT `ck_session_simulated` CHECK (`is_simulated` = 1)
```

## culturepick.credit_accounts

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| user_id | bigint(20) | NO | None | PRI  |
| balance | bigint(20) | NO | 0 |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`user_id`)
CONSTRAINT `fk_account_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
CONSTRAINT `ck_account_balance` CHECK (`balance` >= 0)
```

## culturepick.credit_transactions

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| user_id | bigint(20) | NO | None | MUL  |
| reservation_id | bigint(20) | YES | NULL | MUL  |
| type | varchar(8) | NO | None |   |
| delta | bigint(20) | NO | None |   |
| balance_after | bigint(20) | NO | None |   |
| reversal_of | bigint(20) | YES | NULL | UNI  |
| operation_id | varchar(191) | NO | None | UNI  |
| dataset_key | varchar(64) | NO | 'real' | MUL  |
| created_at | datetime(6) | NO | current_timestamp(6) |   |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_credit_operation` (`operation_id`)
UNIQUE KEY `uq_credit_reversal` (`reversal_of`)
UNIQUE KEY `uq_credit_reservation_type` (`reservation_id`,`type`)
UNIQUE KEY `uq_credit_owner_reservation` (`id`,`user_id`,`reservation_id`)
KEY `fk_credit_user` (`user_id`,`dataset_key`)
KEY `fk_credit_reservation_owner` (`reservation_id`,`user_id`)
KEY `fk_credit_reversal` (`reversal_of`,`user_id`,`reservation_id`)
KEY `ix_credit_user_created` (`user_id`,`created_at`)
KEY `ix_credit_dataset_created` (`dataset_key`,`created_at`)
CONSTRAINT `fk_credit_reservation_owner` FOREIGN KEY (`reservation_id`, `user_id`) REFERENCES `reservations` (`id`, `user_id`)
CONSTRAINT `fk_credit_reversal` FOREIGN KEY (`reversal_of`, `user_id`, `reservation_id`) REFERENCES `credit_transactions` (`id`, `user_id`, `reservation_id`)
CONSTRAINT `fk_credit_user` FOREIGN KEY (`user_id`, `dataset_key`) REFERENCES `users` (`id`, `dataset_key`)
CONSTRAINT `ck_credit_balance` CHECK (`balance_after` >= 0)
CONSTRAINT `ck_credit_shape` CHECK (`type` = 'GRANT' and `delta` >= 0 and `reservation_id` is null and `reversal_of` is null and `operation_id` = concat('signup:',`user_id`) or `type` = 'PURCHASE' and `delta` <= 0 and `reservation_id` is not null and `reversal_of` is null and `operation_id` = concat('reservation:',`reservation_id`,':confirmed') or `type` = 'REFUND' and `delta` >= 0 and `reservation_id` is not null and `reversal_of` is not null and `operation_id` = concat('reservation:',`reservation_id`,':cancelled'))
```

## culturepick.event_outbox

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| event_id | char(36) | NO | None | PRI  |
| event_type | varchar(64) | NO | None |   |
| aggregate_type | varchar(32) | NO | None |   |
| aggregate_id | varchar(64) | NO | None |   |
| aggregate_version | bigint(20) | NO | None |   |
| payload_json | longtext | NO | None |   |
| occurred_at | datetime(6) | NO | None |   |
| request_id | varchar(128) | NO | None |   |
| operation_id | varchar(191) | NO | None | UNI  |
| status | varchar(8) | NO | 'PENDING' | MUL  |
| attempts | tinyint(4) | NO | 0 |   |
| next_retry_at | datetime(6) | NO | current_timestamp(6) |   |
| sent_at | datetime(6) | YES | NULL |   |
| last_error | varchar(512) | YES | NULL |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |

제약·인덱스:

```sql
PRIMARY KEY (`event_id`)
UNIQUE KEY `uq_outbox_operation` (`operation_id`)
KEY `ix_outbox_dispatch` (`status`,`next_retry_at`)
CONSTRAINT `ck_outbox_uuid` CHECK (`event_id` regexp '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
CONSTRAINT `ck_outbox_type` CHECK (`event_type` in ('user_registered','profile_updated','survey_submitted','survey_updated','bookmark_added','bookmark_removed','review_created','review_updated','review_deleted','reservation_confirmed','reservation_cancelled','visit_marked'))
CONSTRAINT `ck_outbox_status` CHECK (`status` in ('PENDING','SENT','FAILED') and `attempts` between 0 and 5)
CONSTRAINT `ck_outbox_sent` CHECK (`status` = 'SENT' and `sent_at` is not null or `status` <> 'SENT' and `sent_at` is null)
CONSTRAINT `ck_outbox_version` CHECK (`aggregate_version` > 0)
```

## culturepick.genres

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| code | varchar(32) | NO | None | UNI  |
| name | varchar(50) | NO | None |   |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_genres_code` (`code`)
```

## culturepick.reservations

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| user_id | bigint(20) | NO | None | MUL  |
| session_id | bigint(20) | NO | None | MUL  |
| quantity | tinyint(4) | NO | None |   |
| unit_credit | bigint(20) | NO | None |   |
| total_credit | bigint(20) | NO | None |   |
| status | varchar(16) | NO | 'CONFIRMED' |   |
| version | bigint(20) | NO | 1 |   |
| dataset_key | varchar(64) | NO | 'real' |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |
| cancelled_at | datetime(6) | YES | NULL |   |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_reservation_owner` (`id`,`user_id`)
KEY `fk_reservation_user` (`user_id`,`dataset_key`)
KEY `ix_reservation_user_created` (`user_id`,`created_at`)
KEY `ix_reservation_session_status` (`session_id`,`status`)
CONSTRAINT `fk_reservation_session` FOREIGN KEY (`session_id`) REFERENCES `content_sessions` (`id`)
CONSTRAINT `fk_reservation_user` FOREIGN KEY (`user_id`, `dataset_key`) REFERENCES `users` (`id`, `dataset_key`)
CONSTRAINT `ck_reservation_quantity` CHECK (`quantity` between 1 and 4)
CONSTRAINT `ck_reservation_total` CHECK (`unit_credit` >= 0 and `total_credit` = `unit_credit` * `quantity`)
CONSTRAINT `ck_reservation_status` CHECK (`status` = 'CONFIRMED' and `cancelled_at` is null or `status` = 'CANCELLED' and `cancelled_at` is not null)
CONSTRAINT `ck_reservation_version` CHECK (`version` > 0)
```

## culturepick.reviews

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| user_id | bigint(20) | NO | None | MUL  |
| content_id | bigint(20) | NO | None | MUL  |
| rating | tinyint(4) | NO | None |   |
| body | text | NO | None |   |
| version | bigint(20) | NO | 1 |   |
| deleted_at | datetime(6) | YES | NULL |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_review_user_content` (`user_id`,`content_id`)
KEY `ix_review_content_active` (`content_id`,`deleted_at`,`created_at`)
CONSTRAINT `fk_review_content` FOREIGN KEY (`content_id`) REFERENCES `contents` (`id`)
CONSTRAINT `fk_review_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
CONSTRAINT `ck_review_rating` CHECK (`rating` between 1 and 5)
CONSTRAINT `ck_review_version` CHECK (`version` > 0)
```

## culturepick.users

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| email | varchar(254) | NO | None | UNI  |
| password_hash | varchar(255) | NO | None |   |
| nickname | varchar(50) | NO | None |   |
| status | varchar(16) | NO | 'ACTIVE' |   |
| dataset_key | varchar(64) | NO | 'real' |   |
| version | bigint(20) | NO | 1 |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_users_email` (`email`)
UNIQUE KEY `uq_users_dataset` (`id`,`dataset_key`)
CONSTRAINT `ck_users_email` CHECK (cast(`email` as char charset binary) = cast(lcase(trim(`email`)) as char charset binary))
CONSTRAINT `ck_users_status` CHECK (`status` in ('ACTIVE','SUSPENDED','WITHDRAWN'))
CONSTRAINT `ck_users_version` CHECK (`version` > 0)
```

## culturepick.user_preferences

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| user_id | bigint(20) | NO | None | PRI  |
| region_code | varchar(32) | YES | NULL |   |
| min_price | bigint(20) | YES | NULL |   |
| max_price | bigint(20) | YES | NULL |   |
| lifestyle_type | varchar(32) | NO | 'ANY' |   |
| version | bigint(20) | NO | 1 |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`user_id`)
CONSTRAINT `fk_preferences_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
CONSTRAINT `ck_preferences_prices` CHECK ((`min_price` is null or `min_price` >= 0) and (`max_price` is null or `max_price` >= 0) and (`min_price` is null or `max_price` is null or `min_price` <= `max_price`))
CONSTRAINT `ck_preferences_lifestyle` CHECK (`lifestyle_type` in ('ANY','RELAXED','ACTIVE','SOCIAL'))
CONSTRAINT `ck_preferences_version` CHECK (`version` > 0)
```

## culturepick.user_preference_genres

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| user_id | bigint(20) | NO | None | PRI  |
| genre_id | bigint(20) | NO | None | PRI  |

제약·인덱스:

```sql
PRIMARY KEY (`user_id`,`genre_id`)
KEY `fk_upg_genre` (`genre_id`)
CONSTRAINT `fk_upg_genre` FOREIGN KEY (`genre_id`) REFERENCES `genres` (`id`)
CONSTRAINT `fk_upg_user` FOREIGN KEY (`user_id`) REFERENCES `user_preferences` (`user_id`)
```

## culturepick.visit_history

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| user_id | bigint(20) | NO | None | MUL  |
| content_id | bigint(20) | NO | None | MUL  |
| reservation_id | bigint(20) | YES | NULL | MUL  |
| visited_at | datetime(6) | NO | None |   |
| source | varchar(32) | NO | 'SELF_REPORTED' |   |
| created_at | datetime(6) | NO | current_timestamp(6) |   |
| updated_at | datetime(6) | NO | current_timestamp(6) |  on update current_timestamp(6) |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_visit_user_content` (`user_id`,`content_id`)
KEY `fk_visit_content` (`content_id`)
KEY `fk_visit_reservation_owner` (`reservation_id`,`user_id`)
CONSTRAINT `fk_visit_content` FOREIGN KEY (`content_id`) REFERENCES `contents` (`id`)
CONSTRAINT `fk_visit_reservation_owner` FOREIGN KEY (`reservation_id`, `user_id`) REFERENCES `reservations` (`id`, `user_id`)
CONSTRAINT `fk_visit_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
CONSTRAINT `ck_visit_source` CHECK (`source` = 'SELF_REPORTED')
```

## culturepick_analytics.clean_events

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| event_id | char(36) | NO | None | PRI  |
| event_type | varchar(64) | NO | None |   |
| occurred_at | datetime(6) | NO | None |   |
| business_date | date | NO | None | MUL  |
| user_id | bigint(20) | YES | NULL | MUL  |
| content_id | bigint(20) | YES | NULL | MUL  |
| operation_id | varchar(191) | YES | NULL | UNI  |
| source | varchar(16) | NO | None |   |
| is_test | tinyint(1) | NO | None |   |
| test_run_id | varchar(64) | YES | NULL |   |
| dataset_key | varchar(64) | NO | None |   |
| properties_json | longtext | NO | None |   |
| normalization_version | int(11) | NO | None |   |
| run_id | char(36) | NO | None | MUL  |

제약·인덱스:

```sql
PRIMARY KEY (`event_id`)
UNIQUE KEY `uq_clean_operation` (`operation_id`)
KEY `fk_clean_run` (`run_id`)
KEY `ix_clean_day_dataset` (`business_date`,`dataset_key`,`event_type`)
KEY `ix_clean_user_time` (`user_id`,`occurred_at`)
KEY `ix_clean_content_time` (`content_id`,`occurred_at`)
CONSTRAINT `fk_clean_run` FOREIGN KEY (`run_id`) REFERENCES `etl_runs` (`run_id`)
CONSTRAINT `ck_clean_date` CHECK (`business_date` = cast(`occurred_at` + interval 9 hour as date))
CONSTRAINT `ck_clean_source` CHECK (`source` in ('browser','server'))
CONSTRAINT `ck_clean_dataset` CHECK (`is_test` = 0 and `test_run_id` is null and `dataset_key` = 'real' or `is_test` = 1 and `test_run_id` is not null and `dataset_key` = `test_run_id` and `dataset_key` <> 'real')
CONSTRAINT `ck_clean_version` CHECK (`normalization_version` > 0)
```

## culturepick_analytics.daily_activity_metrics

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| business_date | date | NO | None | PRI  |
| dataset_key | varchar(64) | NO | None | PRI  |
| event_type | varchar(64) | NO | None | PRI  |
| event_count | bigint(20) | NO | None |   |
| user_count | bigint(20) | NO | None |   |

제약·인덱스:

```sql
PRIMARY KEY (`business_date`,`dataset_key`,`event_type`)
CONSTRAINT `ck_activity_counts` CHECK (`event_count` >= 0 and `user_count` >= 0 and `user_count` <= `event_count`)
```

## culturepick_analytics.daily_content_metrics

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| business_date | date | NO | None | PRI  |
| dataset_key | varchar(64) | NO | None | PRI  |
| content_id | bigint(20) | NO | None | PRI  |
| view_count | bigint(20) | NO | None |   |
| bookmark_add_count | bigint(20) | NO | None |   |
| reservation_count | bigint(20) | NO | None |   |
| cancelled_count | bigint(20) | NO | None |   |
| gross_credit | bigint(20) | NO | None |   |
| refund_credit | bigint(20) | NO | None |   |
| net_credit | bigint(20) | NO | None |   |

제약·인덱스:

```sql
PRIMARY KEY (`business_date`,`dataset_key`,`content_id`)
CONSTRAINT `ck_metrics_counts` CHECK (`view_count` >= 0 and `bookmark_add_count` >= 0 and `reservation_count` >= 0 and `cancelled_count` >= 0 and `gross_credit` >= 0 and `refund_credit` >= 0)
CONSTRAINT `ck_metrics_net` CHECK (`net_credit` = `gross_credit` - `refund_credit`)
```

## culturepick_analytics.etl_checkpoints

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| job_name | varchar(64) | NO | None | PRI  |
| last_success_at | datetime(6) | NO | None |   |

제약·인덱스:

```sql
PRIMARY KEY (`job_name`)
```

## culturepick_analytics.etl_runs

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| run_id | char(36) | NO | None | PRI  |
| window_start | datetime(6) | NO | None |   |
| window_end | datetime(6) | NO | None |   |
| started_at | datetime(6) | NO | current_timestamp(6) |   |
| finished_at | datetime(6) | YES | NULL |   |
| status | varchar(16) | NO | None |   |
| source_counts | longtext | NO | None |   |
| input_count | bigint(20) | NO | 0 |   |
| output_count | bigint(20) | NO | 0 |   |
| rejected_count | bigint(20) | NO | 0 |   |
| complete_sources | longtext | NO | None |   |

제약·인덱스:

```sql
PRIMARY KEY (`run_id`)
CONSTRAINT `ck_etl_status` CHECK (`status` in ('RUNNING','SUCCEEDED','PARTIAL','FAILED'))
CONSTRAINT `ck_etl_window` CHECK (`window_start` <= `window_end`)
CONSTRAINT `ck_etl_counts` CHECK (`input_count` >= 0 and `output_count` >= 0 and `rejected_count` >= 0)
```

## culturepick_analytics.quality_issues

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| id | bigint(20) | NO | None | PRI auto_increment |
| issue_key | varchar(191) | NO | None | UNI  |
| type | varchar(32) | NO | None |   |
| severity | varchar(16) | NO | None |   |
| entity_id | varchar(191) | YES | NULL |   |
| event_id | char(36) | YES | NULL |   |
| expected_json | longtext | YES | NULL |   |
| actual_json | longtext | YES | NULL |   |
| status | varchar(16) | NO | 'OPEN' | MUL  |
| first_seen_at | datetime(6) | NO | current_timestamp(6) |   |
| last_seen_at | datetime(6) | NO | current_timestamp(6) |   |
| resolved_at | datetime(6) | YES | NULL |   |
| run_id | char(36) | NO | None | MUL  |

제약·인덱스:

```sql
PRIMARY KEY (`id`)
UNIQUE KEY `uq_quality_issue` (`issue_key`)
KEY `fk_quality_run` (`run_id`)
KEY `ix_quality_status_type` (`status`,`type`)
CONSTRAINT `fk_quality_run` FOREIGN KEY (`run_id`) REFERENCES `etl_runs` (`run_id`)
CONSTRAINT `ck_quality_type` CHECK (`type` in ('EVENT_DELIVERY_DELAY','MISSING_EVENT','DUPLICATE_OPERATION','INVALID_SCHEMA','ORPHAN_REFERENCE','PAYLOAD_MISMATCH','MISSING_LOG','LEDGER_MISMATCH','EXTRA_SERVER_EVENT'))
CONSTRAINT `ck_quality_severity` CHECK (`severity` in ('INFO','WARNING','ERROR','CRITICAL'))
CONSTRAINT `ck_quality_status` CHECK (`status` in ('PENDING','OPEN','RESOLVED'))
```

## culturepick_analytics.user_genre_features

| 컬럼 | 타입 | NULL | 기본값 | 키/추가 |
|---|---|---|---|---|
| user_id | bigint(20) | NO | None | PRI  |
| genre_id | bigint(20) | NO | None | PRI  |
| dataset_key | varchar(64) | NO | None | PRI  |
| as_of_date | date | NO | None | PRI  |
| interest_score | decimal(12,4) | NO | None |   |
| normalization_version | int(11) | NO | None |   |

제약·인덱스:

```sql
PRIMARY KEY (`user_id`,`genre_id`,`dataset_key`,`as_of_date`)
CONSTRAINT `ck_feature_score` CHECK (`interest_score` >= 0 and `normalization_version` > 0)
```
