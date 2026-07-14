# MedVision Backend V1 Design

## Goal

Define a launchable backend v1 for MedVision using Supabase as the primary backend platform. The backend must support OCR proxying, structured medicine extraction, medicine and schedule storage, dose-event history, and drug-info lookup without exposing third-party API keys to the mobile client.

## Product Scope

MedVision is a personal medicine manager for a single user. The backend exists to support the app's core loop:

1. Upload a medicine packet image.
2. Run OCR through Typhoon server-side.
3. Parse OCR output into editable medicine fields.
4. Save medicines, schedules, and dose history.
5. Fetch general drug information on demand.

The backend is not responsible for local notification delivery. It provides the data the app needs to schedule and track those reminders.

## Stack

- Supabase Auth
- Supabase Postgres
- Supabase Storage
- Supabase Edge Functions
- Typhoon OCR API
- One public drug-info provider, proxied through the backend

## Architecture

### 1. Authentication and user isolation

The app authenticates with Supabase Auth. Every persistent row is owned by one authenticated user. Row Level Security is mandatory on all user data tables. The backend uses the authenticated user id as the primary ownership boundary.

### 2. OCR ingestion flow

The client uploads a medicine packet image to a backend-owned endpoint. The backend validates type and size, stores the image in Supabase Storage, creates a `recognition_jobs` record, calls Typhoon using a server-side secret, stores the raw OCR text, parses the OCR text into structured medicine fields, stores the parsed result, and returns the parsed response to the client.

The OCR endpoint must return a structured response even on partial failure. For example, if Typhoon returns text but parsing confidence is weak, the backend still returns the raw text and marks the parse as low-confidence so the client can force manual confirmation.

### 3. Core data storage

The backend stores:

- `profiles`
- `medicines`
- `schedules`
- `dose_events`
- `recognition_jobs`
- `drug_info_cache`

The client reads and writes medicine, schedule, and dose-event data through backend-owned interfaces. The backend is the source of truth for synced data.

### 4. Drug info lookup

The client never calls a drug-info provider directly. The backend exposes a lookup endpoint, normalizes the query, fetches the result from the chosen provider, stores a short-lived cache entry, and returns a simplified response shape to the client.

### 5. Operational safety

All secrets live in Supabase secrets. All functions emit structured logs. Timeouts, retries, upstream failures, malformed OCR responses, and invalid client payloads all map to normalized API errors.

## Data Model

### `profiles`

- `id uuid primary key` references auth user id
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `medicines`

- `id uuid primary key`
- `user_id uuid not null`
- `name text not null`
- `dosage text not null default ''`
- `form text not null`
- `notes text not null default ''`
- `image_path text`
- `source text not null`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `schedules`

- `id uuid primary key`
- `user_id uuid not null`
- `medicine_id uuid not null`
- `frequency_type text not null`
- `times jsonb not null`
- `with_food boolean not null default false`
- `instructions text not null default ''`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `dose_events`

- `id uuid primary key`
- `user_id uuid not null`
- `medicine_id uuid not null`
- `scheduled_for timestamptz not null`
- `taken_at timestamptz`
- `status text not null`
- `created_at timestamptz not null`

### `recognition_jobs`

- `id uuid primary key`
- `user_id uuid not null`
- `image_path text not null`
- `status text not null`
- `raw_ocr_text text not null default ''`
- `parsed_result jsonb`
- `failure_reason text not null default ''`
- `created_at timestamptz not null`
- `updated_at timestamptz not null`

### `drug_info_cache`

- `id uuid primary key`
- `normalized_query text not null`
- `provider text not null`
- `response_summary jsonb not null`
- `fetched_at timestamptz not null`
- `expires_at timestamptz not null`

## API Surface

### `POST /recognize-medicine`

Request:

- authenticated user
- image upload

Response:

- `jobId`
- `status`
- `rawText`
- `parsedMedicine`
- `parseConfidence`
- `warnings`

### `GET /medicines`
### `POST /medicines`
### `PATCH /medicines/:id`
### `DELETE /medicines/:id`

CRUD for medicine records.

### `GET /schedules`
### `POST /schedules`
### `PATCH /schedules/:id`
### `DELETE /schedules/:id`

CRUD for schedule records.

### `GET /dose-events`
### `POST /dose-events`

List and create dose history records.

### `GET /drug-info`

Query by normalized medicine name and return a simplified drug-info response.

## Parsing strategy

The backend does not trust Typhoon to return perfectly structured fields. Parsing is its own module and follows this order:

1. Extract likely medicine name lines.
2. Extract dosage patterns.
3. Infer medicine form from keywords.
4. Return parse warnings when confidence is low.
5. Preserve raw OCR text for review and fallback behavior.

This keeps OCR-provider output and application-facing data contracts separated.

## Security requirements

- No third-party API key in the client.
- RLS on every user-owned table.
- Storage paths partitioned by user id.
- MIME type and size validation on uploaded images.
- Server-side normalization of all drug-info queries.
- No medicine or OCR contents in analytics events.

## Launch readiness criteria

Backend v1 is launchable when all of the following are true:

- Migrations create every schema object from scratch in a clean environment.
- RLS policies prevent cross-user reads and writes.
- OCR flow succeeds for valid images and fails cleanly for invalid images, timeout cases, and upstream provider failures.
- Medicine, schedule, and dose-event CRUD paths are covered by tests and manual smoke checks.
- Structured logs exist for all function failures.
- Secrets are configured only in the deployment environment.
- There are no known P0 or P1 defects blocking medicine recognition or core CRUD behavior.

## Explicit non-goals

- Caregiver or multi-user sharing
- Medication interaction checking
- Offline OCR
- HIPAA or production-grade compliance claims
- Notification delivery orchestration inside the backend
