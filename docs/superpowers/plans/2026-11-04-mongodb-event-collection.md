# MongoDB Event Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Collect authenticated CulturePick activity events into MongoDB using a 10-event/3-second browser queue.

**Architecture:** Extend `/history/events` with a batch envelope and persist analytics data through a Mongo repository. Keep the existing SQL event write for recommendation history. Frontend events queue in localStorage and flush over the existing authenticated API client.

**Tech Stack:** FastAPI, Pydantic, PyMongo, React, TypeScript, Vite.

**Spec:** `docs/superpowers/specs/2026-11-04-mongodb-event-collection-design.md`

## Global Constraints
- MariaDB remains the source of truth for application state and recommendation history.
- Mongo credentials belong in `backend/.env`, with placeholder-only `.env.example` values.
- Backend routes use `/api/v1` and event writes require Bearer authentication.
- The batch size and browser queue cap are 10; periodic flush interval is 3 seconds.

## Review Focus
- Duplicate event IDs across retries must not create duplicate Mongo documents.
- Mongo failure must not prevent SQL history behavior or browsing; API failure returns a retryable error for frontend queue retention.
- Invalid batch sizes, unknown event types, and malformed event data must return 422.
- Logged-out clients must not send or retain new analytics events.

### Task 1: Backend Mongo event batch
**Files:** Modify `backend/app/core/config.py`, `backend/.env.example`, `backend/requirements.txt`, `backend/requirements-lock.txt`, `backend/app/schemas/__init__.py`, `backend/app/api/v1/history.py`, `backend/app/api/router.py`; create `backend/app/db/mongo.py`; modify `backend/tests/test_service.py`.
**Interfaces:** `EventBatchInput(events: list[EventInput])`; `store_events(events, user_id)` writes MongoDB with unique event IDs; `POST /history/events` accepts either a single event or `{events: [...]}`.
- [ ] Add tests for authenticated batch acceptance, SQL behavior compatibility, invalid/oversized batches, and Mongo deduplication through a fake collection.
- [ ] Run focused tests and confirm they fail for missing batch handling.
- [ ] Implement configurable Mongo client/repository, event schemas, and route behavior.
- [ ] Run focused tests.

### Task 2: Frontend queue and event coverage
**Files:** Create `frontend/src/api/events.ts`; modify `frontend/src/api/client.ts`, `frontend/src/App.tsx`, `frontend/src/pages/Home.tsx`, `Explore.tsx`, `Detail.tsx`, `Collection.tsx`, `MyPage.tsx`, `SurveyDialog.tsx`, `frontend/src/components/ContentCard.tsx`, `frontend/src/api/payments.ts`.
**Interfaces:** `track(type, props?)` adds a typed event; one singleton queue flushes at 10 events or each 3000 ms; authenticated API posts `{events}` to `/history/events`.
- [ ] Add queue tests for count-triggered flush, 3-second flush, retry retention, and authenticated-only collection.
- [ ] Run focused tests and confirm they fail before implementation.
- [ ] Implement event IDs, session/browser identifiers, page metadata, queueing and event instrumentation for service actions.
- [ ] Run frontend build and queue tests.

### Task 3: Contract and setup docs
**Files:** Modify `docs/event-contract.md`, `docs/api-spec.md`, `docs/data-dictionary.md`, `docs/setup.md`.
- [ ] Document event type names, envelope and batch route, Mongo environment setup, and local run instructions.
- [ ] Regenerate `docs/openapi.json` from the backend contract.
- [ ] Run relevant backend/frontend verification.
