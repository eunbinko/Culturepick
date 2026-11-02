-- Canonical DDL for revision 0001_initial. Forward migrations only after release.
CREATE DATABASE IF NOT EXISTS culturepick CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS culturepick_analytics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE culturepick;
SET time_zone = '+00:00';

CREATE TABLE users (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(254) COLLATE utf8mb4_bin NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  nickname VARCHAR(50) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL DEFAULT 'real',
  version BIGINT NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_users_email UNIQUE(email),
  CONSTRAINT uq_users_dataset UNIQUE(id,dataset_key),
  CONSTRAINT ck_users_email CHECK (BINARY email = BINARY LOWER(TRIM(email))),
  CONSTRAINT ck_users_status CHECK (status IN ('ACTIVE','SUSPENDED','WITHDRAWN')),
  CONSTRAINT ck_users_version CHECK (version > 0)
) ENGINE=InnoDB;

CREATE TABLE auth_sessions (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_auth_token UNIQUE(token_hash),
  CONSTRAINT fk_auth_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT ck_auth_token CHECK (token_hash REGEXP '^[0-9a-f]{64}$'),
  INDEX ix_auth_user_expiry(user_id,expires_at)
) ENGINE=InnoDB;

CREATE TABLE user_preferences (
  user_id BIGINT NOT NULL PRIMARY KEY,
  region_code VARCHAR(32) NULL,
  min_price BIGINT NULL,
  max_price BIGINT NULL,
  lifestyle_type VARCHAR(32) NOT NULL DEFAULT 'ANY',
  version BIGINT NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_preferences_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT ck_preferences_prices CHECK ((min_price IS NULL OR min_price>=0) AND (max_price IS NULL OR max_price>=0) AND (min_price IS NULL OR max_price IS NULL OR min_price<=max_price)),
  CONSTRAINT ck_preferences_lifestyle CHECK (lifestyle_type IN ('ANY','RELAXED','ACTIVE','SOCIAL')),
  CONSTRAINT ck_preferences_version CHECK (version>0)
) ENGINE=InnoDB;

CREATE TABLE genres (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name VARCHAR(50) NOT NULL,
  CONSTRAINT uq_genres_code UNIQUE(code)
) ENGINE=InnoDB;

CREATE TABLE user_preference_genres (
  user_id BIGINT NOT NULL,
  genre_id BIGINT NOT NULL,
  PRIMARY KEY(user_id,genre_id),
  CONSTRAINT fk_upg_user FOREIGN KEY(user_id) REFERENCES user_preferences(user_id),
  CONSTRAINT fk_upg_genre FOREIGN KEY(genre_id) REFERENCES genres(id)
) ENGINE=InnoDB;

CREATE TABLE contents (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  external_id VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  title VARCHAR(255) NOT NULL,
  region_code VARCHAR(32) NULL,
  venue_name VARCHAR(255) NULL,
  address VARCHAR(500) NULL,
  start_at DATETIME(6) NULL,
  end_at DATETIME(6) NULL,
  price_min BIGINT NULL,
  price_max BIGINT NULL,
  is_free BOOLEAN NULL,
  image_url VARCHAR(2048) NULL,
  description TEXT NULL,
  source_url VARCHAR(2048) NULL,
  source_updated_at DATETIME(6) NULL,
  collected_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
  deleted_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_content_source UNIQUE(source,external_id),
  CONSTRAINT ck_content_dates CHECK (start_at IS NULL OR end_at IS NULL OR start_at<=end_at),
  CONSTRAINT ck_content_prices CHECK ((price_min IS NULL OR price_min>=0) AND (price_max IS NULL OR price_max>=0) AND (price_min IS NULL OR price_max IS NULL OR price_min<=price_max)),
  CONSTRAINT ck_content_free CHECK (is_free IS NULL OR is_free=0 OR (is_free=1 AND price_min IS NOT NULL AND price_max IS NOT NULL AND price_min=0 AND price_max=0)),
  CONSTRAINT ck_content_status CHECK (status IN ('ACTIVE','INACTIVE')),
  INDEX ix_content_region_start(region_code,start_at)
) ENGINE=InnoDB;

CREATE TABLE content_genres (
  content_id BIGINT NOT NULL,
  genre_id BIGINT NOT NULL,
  PRIMARY KEY(content_id,genre_id),
  CONSTRAINT fk_cg_content FOREIGN KEY(content_id) REFERENCES contents(id),
  CONSTRAINT fk_cg_genre FOREIGN KEY(genre_id) REFERENCES genres(id),
  INDEX ix_cg_genre_content(genre_id,content_id)
) ENGINE=InnoDB;

CREATE TABLE content_sessions (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  content_id BIGINT NOT NULL,
  starts_at DATETIME(6) NOT NULL,
  credit_price BIGINT NOT NULL,
  is_simulated BOOLEAN NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_session_content FOREIGN KEY(content_id) REFERENCES contents(id),
  CONSTRAINT ck_session_price CHECK (credit_price>=0),
  CONSTRAINT ck_session_simulated CHECK (is_simulated=1),
  INDEX ix_session_content_start(content_id,starts_at)
) ENGINE=InnoDB;

CREATE TABLE bookmarks (
  user_id BIGINT NOT NULL,
  content_id BIGINT NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY(user_id,content_id),
  CONSTRAINT fk_bookmark_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT fk_bookmark_content FOREIGN KEY(content_id) REFERENCES contents(id),
  INDEX ix_bookmark_content(content_id)
) ENGINE=InnoDB;

CREATE TABLE reviews (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  content_id BIGINT NOT NULL,
  rating TINYINT NOT NULL,
  body TEXT NOT NULL,
  version BIGINT NOT NULL DEFAULT 1,
  deleted_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_review_user_content UNIQUE(user_id,content_id),
  CONSTRAINT fk_review_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT fk_review_content FOREIGN KEY(content_id) REFERENCES contents(id),
  CONSTRAINT ck_review_rating CHECK (rating BETWEEN 1 AND 5),
  CONSTRAINT ck_review_version CHECK (version>0),
  INDEX ix_review_content_active(content_id,deleted_at,created_at)
) ENGINE=InnoDB;

CREATE TABLE reservations (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  session_id BIGINT NOT NULL,
  quantity TINYINT NOT NULL,
  unit_credit BIGINT NOT NULL,
  total_credit BIGINT NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'CONFIRMED',
  version BIGINT NOT NULL DEFAULT 1,
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL DEFAULT 'real',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  cancelled_at DATETIME(6) NULL,
  CONSTRAINT uq_reservation_owner UNIQUE(id,user_id),
  CONSTRAINT fk_reservation_user FOREIGN KEY(user_id,dataset_key) REFERENCES users(id,dataset_key),
  CONSTRAINT fk_reservation_session FOREIGN KEY(session_id) REFERENCES content_sessions(id),
  CONSTRAINT ck_reservation_quantity CHECK (quantity BETWEEN 1 AND 4),
  CONSTRAINT ck_reservation_total CHECK (unit_credit>=0 AND total_credit=unit_credit*quantity),
  CONSTRAINT ck_reservation_status CHECK ((status='CONFIRMED' AND cancelled_at IS NULL) OR (status='CANCELLED' AND cancelled_at IS NOT NULL)),
  CONSTRAINT ck_reservation_version CHECK (version>0),
  INDEX ix_reservation_user_created(user_id,created_at),
  INDEX ix_reservation_session_status(session_id,status)
) ENGINE=InnoDB;

CREATE TABLE visit_history (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  content_id BIGINT NOT NULL,
  reservation_id BIGINT NULL,
  visited_at DATETIME(6) NOT NULL,
  source VARCHAR(32) NOT NULL DEFAULT 'SELF_REPORTED',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_visit_user_content UNIQUE(user_id,content_id),
  CONSTRAINT fk_visit_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT fk_visit_content FOREIGN KEY(content_id) REFERENCES contents(id),
  CONSTRAINT fk_visit_reservation_owner FOREIGN KEY(reservation_id,user_id) REFERENCES reservations(id,user_id),
  CONSTRAINT ck_visit_source CHECK (source='SELF_REPORTED')
) ENGINE=InnoDB;

CREATE TABLE credit_accounts (
  user_id BIGINT NOT NULL PRIMARY KEY,
  balance BIGINT NOT NULL DEFAULT 0,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_account_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT ck_account_balance CHECK (balance>=0)
) ENGINE=InnoDB;

CREATE TABLE credit_transactions (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  reservation_id BIGINT NULL,
  type VARCHAR(8) NOT NULL,
  delta BIGINT NOT NULL,
  balance_after BIGINT NOT NULL,
  reversal_of BIGINT NULL,
  operation_id VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL DEFAULT 'real',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_credit_operation UNIQUE(operation_id),
  CONSTRAINT uq_credit_reversal UNIQUE(reversal_of),
  CONSTRAINT uq_credit_reservation_type UNIQUE(reservation_id,type),
  CONSTRAINT uq_credit_owner_reservation UNIQUE(id,user_id,reservation_id),
  CONSTRAINT fk_credit_user FOREIGN KEY(user_id,dataset_key) REFERENCES users(id,dataset_key),
  CONSTRAINT fk_credit_reservation_owner FOREIGN KEY(reservation_id,user_id) REFERENCES reservations(id,user_id),
  CONSTRAINT fk_credit_reversal FOREIGN KEY(reversal_of,user_id,reservation_id) REFERENCES credit_transactions(id,user_id,reservation_id),
  CONSTRAINT ck_credit_balance CHECK (balance_after>=0),
  CONSTRAINT ck_credit_shape CHECK (
    (type='GRANT' AND delta>=0 AND reservation_id IS NULL AND reversal_of IS NULL AND operation_id=CONCAT('signup:',user_id)) OR
    (type='PURCHASE' AND delta<=0 AND reservation_id IS NOT NULL AND reversal_of IS NULL AND operation_id=CONCAT('reservation:',reservation_id,':confirmed')) OR
    (type='REFUND' AND delta>=0 AND reservation_id IS NOT NULL AND reversal_of IS NOT NULL AND operation_id=CONCAT('reservation:',reservation_id,':cancelled'))
  ),
  INDEX ix_credit_user_created(user_id,created_at),
  INDEX ix_credit_dataset_created(dataset_key,created_at)
) ENGINE=InnoDB;

CREATE TABLE api_idempotency (
  user_id BIGINT NOT NULL,
  operation VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `key` VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  request_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  response_json JSON NULL,
  completed_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY(user_id,operation,`key`),
  CONSTRAINT fk_idempotency_user FOREIGN KEY(user_id) REFERENCES users(id),
  CONSTRAINT ck_idempotency_hash CHECK (request_hash REGEXP '^[0-9a-f]{64}$'),
  CONSTRAINT ck_idempotency_response CHECK ((completed_at IS NULL AND response_json IS NULL) OR (completed_at IS NOT NULL AND response_json IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE event_outbox (
  event_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  event_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_type VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  aggregate_version BIGINT NOT NULL,
  payload_json JSON NOT NULL,
  occurred_at DATETIME(6) NOT NULL,
  request_id VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  operation_id VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  status VARCHAR(8) NOT NULL DEFAULT 'PENDING',
  attempts TINYINT NOT NULL DEFAULT 0,
  next_retry_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  sent_at DATETIME(6) NULL,
  last_error VARCHAR(512) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT uq_outbox_operation UNIQUE(operation_id),
  CONSTRAINT ck_outbox_uuid CHECK (event_id REGEXP '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'),
  CONSTRAINT ck_outbox_type CHECK (event_type IN ('user_registered','profile_updated','survey_submitted','survey_updated','bookmark_added','bookmark_removed','review_created','review_updated','review_deleted','reservation_confirmed','reservation_cancelled','visit_marked')),
  CONSTRAINT ck_outbox_status CHECK (status IN ('PENDING','SENT','FAILED') AND attempts BETWEEN 0 AND 5),
  CONSTRAINT ck_outbox_sent CHECK ((status='SENT' AND sent_at IS NOT NULL) OR (status<>'SENT' AND sent_at IS NULL)),
  CONSTRAINT ck_outbox_version CHECK (aggregate_version>0),
  INDEX ix_outbox_dispatch(status,next_retry_at)
) ENGINE=InnoDB;

CREATE TABLE collection_runs (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  source VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  started_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  finished_at DATETIME(6) NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'RUNNING',
  read_count BIGINT NOT NULL DEFAULT 0,
  insert_count BIGINT NOT NULL DEFAULT 0,
  update_count BIGINT NOT NULL DEFAULT 0,
  reject_count BIGINT NOT NULL DEFAULT 0,
  error_code VARCHAR(64) NULL,
  CONSTRAINT ck_collection_status CHECK (status IN ('RUNNING','SUCCEEDED','FAILED','PARTIAL')),
  CONSTRAINT ck_collection_counts CHECK (read_count>=0 AND insert_count>=0 AND update_count>=0 AND reject_count>=0)
) ENGINE=InnoDB;

USE culturepick_analytics;

CREATE TABLE etl_runs (
  run_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  window_start DATETIME(6) NOT NULL,
  window_end DATETIME(6) NOT NULL,
  started_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  finished_at DATETIME(6) NULL,
  status VARCHAR(16) NOT NULL,
  source_counts JSON NOT NULL,
  input_count BIGINT NOT NULL DEFAULT 0,
  output_count BIGINT NOT NULL DEFAULT 0,
  rejected_count BIGINT NOT NULL DEFAULT 0,
  complete_sources JSON NOT NULL,
  CONSTRAINT ck_etl_status CHECK (status IN ('RUNNING','SUCCEEDED','PARTIAL','FAILED')),
  CONSTRAINT ck_etl_window CHECK (window_start<=window_end),
  CONSTRAINT ck_etl_counts CHECK (input_count>=0 AND output_count>=0 AND rejected_count>=0)
) ENGINE=InnoDB;

CREATE TABLE etl_checkpoints (
  job_name VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  last_success_at DATETIME(6) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE clean_events (
  event_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
  event_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  occurred_at DATETIME(6) NOT NULL,
  business_date DATE NOT NULL,
  user_id BIGINT NULL,
  content_id BIGINT NULL,
  operation_id VARCHAR(191) COLLATE utf8mb4_bin NULL,
  source VARCHAR(16) NOT NULL,
  is_test BOOLEAN NOT NULL,
  test_run_id VARCHAR(64) COLLATE utf8mb4_bin NULL,
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  properties_json JSON NOT NULL,
  normalization_version INT NOT NULL,
  run_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  CONSTRAINT fk_clean_run FOREIGN KEY(run_id) REFERENCES etl_runs(run_id),
  CONSTRAINT uq_clean_operation UNIQUE(operation_id),
  CONSTRAINT ck_clean_date CHECK (business_date=DATE(occurred_at + INTERVAL 9 HOUR)),
  CONSTRAINT ck_clean_source CHECK (source IN ('browser','server')),
  CONSTRAINT ck_clean_dataset CHECK ((is_test=0 AND test_run_id IS NULL AND dataset_key='real') OR (is_test=1 AND test_run_id IS NOT NULL AND dataset_key=test_run_id AND dataset_key<>'real')),
  CONSTRAINT ck_clean_version CHECK (normalization_version>0),
  INDEX ix_clean_day_dataset(business_date,dataset_key,event_type),
  INDEX ix_clean_user_time(user_id,occurred_at),
  INDEX ix_clean_content_time(content_id,occurred_at)
) ENGINE=InnoDB;

CREATE TABLE quality_issues (
  id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  issue_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  type VARCHAR(32) NOT NULL,
  severity VARCHAR(16) NOT NULL,
  entity_id VARCHAR(191) COLLATE utf8mb4_bin NULL,
  event_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
  expected_json JSON NULL,
  actual_json JSON NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'OPEN',
  first_seen_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_seen_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  resolved_at DATETIME(6) NULL,
  run_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  CONSTRAINT uq_quality_issue UNIQUE(issue_key),
  CONSTRAINT fk_quality_run FOREIGN KEY(run_id) REFERENCES etl_runs(run_id),
  CONSTRAINT ck_quality_type CHECK (type IN ('EVENT_DELIVERY_DELAY','MISSING_EVENT','DUPLICATE_OPERATION','INVALID_SCHEMA','ORPHAN_REFERENCE','PAYLOAD_MISMATCH','MISSING_LOG','LEDGER_MISMATCH','EXTRA_SERVER_EVENT')),
  CONSTRAINT ck_quality_severity CHECK (severity IN ('INFO','WARNING','ERROR','CRITICAL')),
  CONSTRAINT ck_quality_status CHECK (status IN ('PENDING','OPEN','RESOLVED')),
  INDEX ix_quality_status_type(status,type)
) ENGINE=InnoDB;

CREATE TABLE daily_activity_metrics (
  business_date DATE NOT NULL,
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  event_type VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  event_count BIGINT NOT NULL,
  user_count BIGINT NOT NULL,
  PRIMARY KEY(business_date,dataset_key,event_type),
  CONSTRAINT ck_activity_counts CHECK (event_count>=0 AND user_count>=0 AND user_count<=event_count)
) ENGINE=InnoDB;

CREATE TABLE daily_content_metrics (
  business_date DATE NOT NULL,
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  content_id BIGINT NOT NULL,
  view_count BIGINT NOT NULL,
  bookmark_add_count BIGINT NOT NULL,
  reservation_count BIGINT NOT NULL,
  cancelled_count BIGINT NOT NULL,
  gross_credit BIGINT NOT NULL,
  refund_credit BIGINT NOT NULL,
  net_credit BIGINT NOT NULL,
  PRIMARY KEY(business_date,dataset_key,content_id),
  CONSTRAINT ck_metrics_counts CHECK (view_count>=0 AND bookmark_add_count>=0 AND reservation_count>=0 AND cancelled_count>=0 AND gross_credit>=0 AND refund_credit>=0),
  CONSTRAINT ck_metrics_net CHECK (net_credit=gross_credit-refund_credit)
) ENGINE=InnoDB;

CREATE TABLE user_genre_features (
  user_id BIGINT NOT NULL,
  genre_id BIGINT NOT NULL,
  dataset_key VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
  as_of_date DATE NOT NULL,
  interest_score DECIMAL(12,4) NOT NULL,
  normalization_version INT NOT NULL,
  PRIMARY KEY(user_id,genre_id,dataset_key,as_of_date),
  CONSTRAINT ck_feature_score CHECK (interest_score>=0 AND normalization_version>0)
) ENGINE=InnoDB;

USE culturepick;
