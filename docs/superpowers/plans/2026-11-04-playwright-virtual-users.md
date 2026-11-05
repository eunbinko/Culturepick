# Playwright Virtual Users Implementation Plan

> **For agentic workers:** Execute tasks natively in this session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement persona-driven Python Playwright virtual users that register, save preferences, browse CulturePick, and write isolated JSON activity results.

**Architecture:** A standard-library JSON config supplies site, product types, personas, action weights, and pacing. An Async Playwright runner uses visible Chromium, guarded DOM actions, per-action recovery, and secret-free JSON output.

**Tech Stack:** Python 3.11+, Playwright Async API, Chromium, JSON, pytest.

**Spec:** `docs/superpowers/specs/2026-11-04-playwright-virtual-users-design.md`

## Global Constraints

- Use Python Playwright Async API and headed Chromium.
- Select each next action via `random.choices()` and irregular waits via `random.uniform()`.
- Read persona Markdown files and keep product, personas, behavior weights, timing, and target in one JSON config.
- Skip absent or non-interactive elements; isolate ordinary action failures.
- Never write passwords, access tokens, or response headers to logs/results.
- Run against local site by default; never create payment or reservation data.

## Review Focus

- Malformed probabilities and paths fail early with actionable configuration errors.
- Missing UI controls produce `skipped` actions while the run continues.
- Registration conflicts do not leak passwords and may use the configured login fallback.
- Review text and search terms satisfy actual UI validation and URL encoding.
- Results remain valid JSON when browser startup or an individual action fails.

---

### Task 1: Configuration and personas

**Files:**
- Create: `scripts/virtual_users/config.json`
- Create: `scripts/virtual_users/personas/*.md`
- Create: `scripts/virtual_users/core.py`
- Test: `tests/test_virtual_users.py`

**Interfaces:**
- `load_config(path) -> dict` validates required sections, bounds, weights, and persona paths.
- `load_persona(path) -> Persona` parses Markdown sections for name, categories, tags, search terms, and browsing preferences.
- `Persona` is an immutable dataclass; no untrusted Markdown is executed.

- [ ] Write failing parser/config tests for valid files, invalid weights, missing persona files, and defaults.
- [ ] Run focused pytest and confirm failures are due to missing interfaces.
- [ ] Implement configuration and Markdown parsing plus representative personas and safe local defaults.
- [ ] Rerun focused tests and confirm they pass.

### Task 2: Async browser actions

**Files:**
- Create: `scripts/virtual_users/run.py`
- Modify: `requirements.txt`
- Test: `tests/test_virtual_users.py`

**Interfaces:**
- `Simulator(config, persona, browser, rng=random)`: one authenticated user journey.
- `run_action(name) -> ActionResult`: guarded UI operation and isolated status recording.
- `run_user(config, persona) -> dict`: creates an independent browser context and user account.

- [ ] Write failing tests for weighted random selection, uniform inter-action delay, absent-control skipping, continuation after exceptions, and safe result fields.
- [ ] Run focused pytest and confirm the intended failures.
- [ ] Implement registration, preference survey, login fallback, and available actions: home, category, search, listing, detail, scroll, bookmark, bookmark verification, review, back, and finish.
- [ ] Add Playwright to root Python requirements and document browser install/run options in the CLI help.
- [ ] Rerun focused tests and confirm they pass.

### Task 3: Run output and CLI

**Files:**
- Modify: `scripts/virtual_users/run.py`
- Modify: `scripts/virtual_users/config.json`
- Test: `tests/test_virtual_users.py`

- [ ] Write failing tests for per-run output naming, category/search generation, viewed-tag counts, and JSON secret redaction.
- [ ] Run focused pytest and confirm failures.
- [ ] Implement CLI overrides for user count, actions per user, config path, base URL, and output path; serialize one run JSON per invocation.
- [ ] Rerun focused tests and confirm they pass.

### Task 4: Local browser verification

**Files:**
- Modify: `docs/testing.md`
- Modify: `scripts/virtual_users/README.md`

- [ ] Run the focused Python test module and repository Python suite using the configured isolated test database.
- [ ] Run one headed Chromium user against the local site, verify registration/preferences/recommendations/bookmark/review, and inspect JSON for valid output and secret absence.
- [ ] Document local use, config fields, cleanup of generated test accounts, and browser installation.
