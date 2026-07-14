# AGENTS.md - MedTrack

Context for AI coding agents (Claude Code, Cursor, etc.) working in this repo.
Human contributors: this doubles as an onboarding doc.

> This file describes intent and conventions. Where reality and this file disagree, fix the code or update this file - don't leave them out of sync.

---

## Project summary

MedTrack is a mobile app that lets a user photograph a medicine packet to log it into a personal digital data bank, then reminds them when to take each medicine.

- **Primary users:** the elderly and people managing many daily medications.
- **Scope:** personal-use utility. **No** social, community, feed, or multi-user features.
- **Team:** 2 people. Optimize for small-team velocity - prefer managed services over self-hosted infra.
- **Stage:** early build. A demo/pitch is the near-term target, not a production launch.

The core loop is: **photograph medicine -> confirm extracted info -> set schedule -> get reminder -> mark as taken -> view history.**

---

## Golden rules (read before writing code)

1. **Elderly-first UX is a hard requirement, not polish.** Large text, high contrast, minimal taps, big unambiguous buttons. The core capture flow (camera -> confirm -> done) should be ~3 taps. If a change makes the app harder for a non-technical older user, it's wrong.
2. **The "confirm & edit" screen after OCR is mandatory.** OCR/recognition is never assumed correct. Never auto-save a recognized medicine without a user confirmation step.
3. **Always keep a manual fallback.** Every camera/OCR path must have an "add/edit manually" escape hatch. Damaged packets and failed recognition are normal, not edge cases.
4. **Stay in scope.** Do not add social, community, caregiver-sharing, or interaction-checking features (see "Explicitly out of scope"). If a task seems to require one, stop and flag it.
5. **This is health data.** Even though compliance is deferred for the demo, don't log medicine data to third parties, don't put it in analytics events, and don't hardcode it into fixtures that get committed. Treat it as sensitive by default.
6. **Ship testable slices.** Prefer changes that leave the app runnable and demoable. Don't land a half-wired feature that breaks the core loop.

---

## Tech stack

- **App framework:** native iOS with SwiftUI and SwiftData.
- **Backend / data:** Supabase Auth, Postgres, Storage, RLS, and Edge Functions.
- **Recognition:** Typhoon OCR, called only through the backend proxy.
- **Drug info:** public drug database API proxied through the backend.

When you introduce or change any of the above, update this file in the same change.

---

## Commands

```bash
# Backend tests
npm --prefix backend test

# Backend lint-style syntax check for JS modules
npm --prefix backend run lint
```

The iOS app build and test commands are still not documented in this repo. If you need them, inspect the project and add them rather than inventing output.

---

## Architecture & data model

The domain is small. Keep it that way.

Core entities:
- **Medicine** - name, dosage, form (pill/liquid/etc.), photo, notes, and frequency note.
- **Schedule** - belongs to a Medicine. Frequency/times plus flags like "with food."
- **DoseEvent / history log** - a record that a scheduled dose was taken / skipped / missed, with a timestamp.
- **RecognitionJob** - tracks OCR uploads, raw OCR text, parsed result, and failure reason.

Design notes for agents:
- A Medicine can have multiple scheduled times; overlapping reminder times across different medicines must be bundled on the app side rather than spammed.
- Keep recognition logic isolated behind a single service/module so the provider can be swapped without touching UI.
- Backend files live under `backend/` and `supabase/`; read `backend/AGENTS.md` when working there.

---

## Conventions

- **Naming:** clear over clever. This is a small codebase maintained by 2 people; favor readability.
- **Accessibility:** every interactive element needs an accessible label and a large enough touch target. This is core to the product, not optional.
- **Comments:** explain why, not what. Flag anything provisional with `TODO:` or `HACK:` so it's greppable.
- **Secrets:** never commit API keys (OCR service, drug API, Supabase secrets). Use env/config files that are gitignored. If you spot a committed secret, stop and flag it.
- **Commits/PRs:** small and scoped to one phase task where possible. Reference the relevant `plan.md` phase.

---

## Explicitly out of scope (do not build)

Flag and stop if a task seems to require any of these - they were deliberately deferred:

- Caregiver / family shared access, and any multi-user account model.
- Medicine interaction checking.
- Offline / on-device OCR.
- Any social, community, feed, or sharing feature.
- HIPAA / medical-data compliance work - deferred for the demo, and must not be claimed.

---

## Working agreement for agents

- If a task is ambiguous or seems to pull you out of scope, ask or flag rather than guessing.
- Don't fabricate command output, test results, or that something works - run it or say you couldn't.
- Prefer the smallest change that satisfies the task and keeps the core loop demoable.
- When you finish, state what you changed, what you ran to verify it, and anything left as a TODO.
