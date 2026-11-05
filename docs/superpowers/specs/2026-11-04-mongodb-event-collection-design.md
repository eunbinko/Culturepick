# MongoDB event collection design

- Intent: collect signed-in CulturePick users' actions in MongoDB to support the 100-user Playwright exercise.
- Goals: preserve the existing `/history/events` route, accept batches up to 10, deduplicate by `event_id`, and persist the supplied event envelope (`event_id`, `type`, `occurred_at`, `session_id`, `anonymous_id`, `page`, `props`, `schema_version`) plus authenticated `user_id`.
- Non-goals: anonymous event collection and replacing MariaDB's existing recommendation/history records.
- Approach: extend the authenticated history endpoint with a batch payload, store raw analytics events in a Mongo collection, and keep the existing single-event MariaDB behavior for recommendation history compatibility.
- Frontend: keep a localStorage queue capped at 10; flush at 10 and every 3 seconds when non-empty; retain failed events for retry. Generate session and browser identifiers locally, but send events only while authenticated.
- Event types: `page_view`, `search`, `filter_use`, `content_view`, `recommendation_impression`, `recommendation_click`, `bookmark_add`, `bookmark_remove`, `review_submit`, `review_delete`, `survey_submit`, `reservation_checkout_started`, `payment_verified`, `payment_cancelled`.
- Storage: configure Mongo URI/database/collection via environment variables; defaults target `192.168.0.24:27107`, database `culturepick_events`, collection `events`. Credentials are only read from local env, never committed.
- Failure behavior: analytics transport errors do not block user actions; buffered events remain queued.
