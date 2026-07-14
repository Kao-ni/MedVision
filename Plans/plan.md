# MedVision Backend V1 Plan

**What it is:** A backend-first execution plan for launching MedVision v1 on Supabase. This plan covers OCR proxying, structured medicine extraction, cloud data storage, dose history, drug-info lookup, security, testing, and deployment. It does not cover iOS UI work except where the backend contract must support the app.

**Launch objective:** Ship a backend that can be deployed as a real v1 service for a single-user personal medicine app, with no known critical defects, no exposed secrets, and clear operational visibility.

**Guiding principles for every phase:**
- Keep the backend as the owner of secrets, OCR orchestration, parsing, and cloud data.
- Prefer the smallest architecture that is deployable, testable, and recoverable in production.
- Treat medicine data as sensitive even though formal compliance work is out of scope.
- Launch readiness means no known P0 or P1 defects, reproducible migrations, tested failure handling, and basic observability.

---

## Locked v1 decisions

- [x] **Backend platform: Supabase.** Use Supabase Auth, Postgres, Storage, Edge Functions, and RLS as the primary backend stack.
- [x] **OCR provider: Typhoon OCR via backend proxy.** The mobile app must never call Typhoon directly.
- [x] **Data ownership: cloud-backed v1.** Medicines, schedules, dose events, and OCR job records are stored in Supabase.
- [x] **Scope model: personal single-user app.** No caregiver, family, or team access in v1.
- [x] **Drug info access: backend-proxied.** The app must not call public drug APIs directly.

---

## Phase 0 - Backend foundation and launch contract

**Goal:** Remove architecture ambiguity and establish the minimum backend contract required for a deployable v1.

- [ ] Define the canonical API surface for `recognize-medicine`, `medicines`, `schedules`, `dose-events`, and `drug-info`
- [ ] Define the exact database schema for `profiles`, `medicines`, `schedules`, `dose_events`, `recognition_jobs`, and `drug_info_cache`
- [ ] Choose the v1 auth path in Supabase Auth and document how the mobile app obtains and refreshes a session
- [ ] Define storage rules for medicine packet images, including per-user folder layout and retention behavior
- [ ] Define normalized error shapes for validation errors, auth failures, OCR upstream failures, timeouts, and not-found cases
- [ ] Document launch severity definitions: `P0`, `P1`, `P2`, and what blocks release
- [ ] Decide the drug-info provider for v1 and document query limits, response mapping, and fallback behavior

**Exit criteria:** The backend contracts are fully written down, every persistent entity has a schema, and no major backend decision remains implicit.

---

## Phase 1 - Supabase project setup and schema

**Goal:** Create the backend project skeleton, database, policies, and secrets model.

- [ ] Create the Supabase project and configure environments for local development and production
- [ ] Add migration files for all tables, indexes, constraints, and timestamp behavior
- [ ] Create RLS policies for every user-owned table
- [ ] Set up storage buckets and access rules for medicine packet images
- [ ] Configure environment secrets for Typhoon and the drug-info provider
- [ ] Add seed data and local development helpers for smoke testing
- [ ] Add CI checks for migrations, function tests, and linting

**Exit criteria:** A clean environment can be created from migrations, storage and RLS work correctly, and secrets are not stored in source control.

---

## Phase 2 - OCR ingestion and structured parsing

**Goal:** Deliver the core differentiator: secure image recognition through the backend.

- [ ] Build the `recognize-medicine` endpoint in a Supabase Edge Function
- [ ] Validate image type, file size, and authenticated ownership before processing
- [ ] Store the uploaded packet image in Supabase Storage and create a `recognition_jobs` record
- [ ] Call Typhoon server-side with timeout and retry rules
- [ ] Persist raw OCR text and upstream metadata needed for debugging
- [ ] Implement a dedicated parsing module that converts OCR text into `{ name, dosage, form, notes }`
- [ ] Return structured parse warnings and confidence indicators when extraction is weak
- [ ] Ensure OCR failure cases return normalized, app-safe errors without exposing provider secrets

**Exit criteria:** A valid image can be uploaded, processed by Typhoon, parsed into medicine fields, and returned with predictable success or failure responses.

---

## Phase 3 - Core medicine, schedule, and history APIs

**Goal:** Make the backend the source of truth for medicine tracking data.

- [ ] Implement medicine CRUD endpoints backed by the `medicines` table
- [ ] Implement schedule CRUD endpoints backed by the `schedules` table
- [ ] Implement dose-event listing and creation backed by the `dose_events` table
- [ ] Enforce user ownership and record-level authorization on every query and mutation
- [ ] Validate payloads for schedule shape, supported medicine forms, and allowed dose-event statuses
- [ ] Add pagination and stable ordering where list endpoints can grow over time
- [ ] Preserve compatibility with app-side manual medicine entry when OCR is unavailable

**Exit criteria:** The app can store and retrieve medicines, schedules, and dose history entirely through the backend without cross-user leakage or malformed data acceptance.

---

## Phase 4 - Drug info proxy and caching

**Goal:** Add backend-owned enrichment for medicine details without exposing third-party APIs to the client.

- [ ] Implement the `drug-info` lookup endpoint in a separate Edge Function or isolated module
- [ ] Normalize user queries before provider lookup
- [ ] Map provider responses into a simple app-facing format such as use, warnings, and common side effects
- [ ] Cache lookup results in `drug_info_cache` with an explicit expiration policy
- [ ] Return a graceful `info not found` response when no useful result exists
- [ ] Handle provider rate limits and upstream errors without breaking medicine detail screens

**Exit criteria:** The backend can return simplified drug information for known medicines and fail safely when the provider has no result or is unavailable.

---

## Phase 5 - Hardening, observability, and release readiness

**Goal:** Raise the backend from feature-complete to launchable.

- [ ] Add unit tests for OCR parsing and query normalization
- [ ] Add integration tests for Edge Functions, database writes, and storage behavior
- [ ] Add policy tests proving RLS blocks unauthorized cross-user access
- [ ] Add contract tests for request and response shapes on all public endpoints
- [ ] Add structured logging and failure metadata for OCR, drug lookup, and CRUD mutations
- [ ] Add rate limiting or abuse controls appropriate for a small personal-use v1
- [ ] Run manual smoke tests for OCR success, OCR timeout, invalid image upload, medicine CRUD, schedule CRUD, dose-event creation, and drug-info lookup
- [ ] Prepare release checklist items for secret rotation, migration rollout, rollback steps, and production environment verification

**Exit criteria:** The backend passes automated tests, manual smoke tests, and release checks, with no known P0 or P1 defects.

---

## Release gate

Do not call the backend v1 launched until all of the following are true:

- [ ] All migrations run successfully from an empty database
- [ ] All Edge Functions deploy successfully in the target environment
- [ ] All secrets are configured only in Supabase environment settings
- [ ] RLS policies are verified against cross-user access attempts
- [ ] OCR jobs record both success and failure states clearly
- [ ] Public API responses are documented and stable
- [ ] Monitoring or log access is available for function failures
- [ ] There are no known P0 or P1 defects in OCR, medicine CRUD, schedule CRUD, dose history, or drug-info lookup

---

## Explicitly deferred

These items are intentionally out of scope for backend v1:

- Caregiver or family shared access
- Multi-user collaboration or team accounts
- Medication interaction checking
- Offline or on-device OCR
- Notification scheduling inside the backend
- HIPAA or other formal compliance claims
- Analytics pipelines that include medicine-identifying data

---

## Suggested immediate next step

Start with **Phase 0** and convert the backend contract into concrete schema, endpoint, and error-shape documents before writing implementation code. That is the shortest path to a stable Supabase v1.
