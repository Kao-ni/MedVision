# MedVision Backend V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Supabase-backed backend v1 for MedVision that supports OCR proxying, structured medicine parsing, medicine and schedule storage, dose history, and drug-info lookup.

**Architecture:** The backend is implemented as Supabase schema, policies, storage rules, and Edge Functions with small shared modules for validation, parsing, and response shaping. Pure logic is kept in reusable JavaScript modules so it can be tested locally with Node before deployment-specific wiring is added.

**Tech Stack:** Supabase Postgres, Supabase Storage, Supabase Edge Functions, JavaScript ES modules, Node built-in test runner

## Global Constraints

- Keep the backend as the owner of secrets, OCR orchestration, parsing, and cloud data.
- Prefer the smallest architecture that is deployable, testable, and recoverable in production.
- Treat medicine data as sensitive even though formal compliance work is out of scope.
- Launch readiness means no known P0 or P1 defects, reproducible migrations, tested failure handling, and basic observability.
- No third-party API key in the client.
- RLS on every user-owned table.
- Storage paths partitioned by user id.
- MIME type and size validation on uploaded images.
- Server-side normalization of all drug-info queries.
- No medicine or OCR contents in analytics events.

---

### Task 1: Scaffold backend workspace

**Files:**
- Create: `backend/AGENTS.md`
- Create: `backend/package.json`
- Create: `backend/README.md`
- Create: `supabase/config.toml`

**Interfaces:**
- Consumes: approved backend design in `docs/superpowers/specs/2026-07-13-medvision-backend-v1-design.md`
- Produces: backend workspace structure and local commands

- [ ] Add backend workspace files
- [ ] Define test and lint commands in `backend/package.json`
- [ ] Document local setup and deployment assumptions

### Task 2: Add schema and policies

**Files:**
- Create: `supabase/migrations/20260713100000_backend_v1.sql`
- Create: `supabase/seed.sql`

**Interfaces:**
- Consumes: v1 entities and launch constraints
- Produces: Postgres tables, enums, indexes, triggers, storage bucket, RLS policies

- [ ] Create schema for profiles, medicines, schedules, dose_events, recognition_jobs, and drug_info_cache
- [ ] Create helper trigger for `updated_at`
- [ ] Add storage bucket and per-user policies
- [ ] Add RLS policies for all user-owned tables

### Task 3: Add shared runtime modules

**Files:**
- Create: `backend/src/contracts.js`
- Create: `backend/src/errors.js`
- Create: `backend/src/validation.js`
- Create: `backend/src/parseMedicine.js`
- Create: `backend/src/drugInfo.js`
- Create: `backend/tests/parseMedicine.test.js`
- Create: `backend/tests/validation.test.js`
- Create: `backend/tests/drugInfo.test.js`

**Interfaces:**
- Consumes: OCR text and request payloads
- Produces: validated payloads, normalized errors, parsed medicine result, normalized drug-info result

- [ ] Write failing tests for parsing, validation, and drug-info normalization
- [ ] Implement shared modules to satisfy tests
- [ ] Verify all shared-module tests pass

### Task 4: Implement recognition and drug-info functions

**Files:**
- Create: `supabase/functions/_shared/http.js`
- Create: `supabase/functions/_shared/runtime.js`
- Create: `supabase/functions/recognize-medicine/index.ts`
- Create: `supabase/functions/drug-info/index.ts`

**Interfaces:**
- Consumes: authenticated requests, storage upload metadata, Typhoon responses, drug-info provider responses
- Produces: normalized HTTP responses for OCR and drug-info lookup

- [ ] Implement request/response helpers
- [ ] Implement OCR function flow and failure mapping
- [ ] Implement drug-info lookup flow and cache behavior

### Task 5: Implement core CRUD functions

**Files:**
- Create: `supabase/functions/medicines/index.ts`
- Create: `supabase/functions/schedules/index.ts`
- Create: `supabase/functions/dose-events/index.ts`

**Interfaces:**
- Consumes: authenticated CRUD requests
- Produces: stable JSON contracts for medicine, schedule, and dose-event endpoints

- [ ] Implement medicine CRUD routes
- [ ] Implement schedule CRUD routes
- [ ] Implement dose-event list and create routes
- [ ] Align dose-event statuses with the existing Swift app model

### Task 6: Sync repo guidance and verify

**Files:**
- Modify: `MedVision/Plans/AGENTS.md`

**Interfaces:**
- Consumes: final backend scaffold and commands
- Produces: repo guidance aligned with reality

- [ ] Update guidance to reflect native iOS app plus Supabase backend
- [ ] Run `node --test backend/tests/*.test.js`
- [ ] Report actual verification status and remaining deployment prerequisites
