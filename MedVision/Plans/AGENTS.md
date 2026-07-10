# AGENTS.md — MedTrack

Context for AI coding agents (Claude Code, Cursor, etc.) working in this repo.
Human contributors: this doubles as an onboarding doc.

> This file describes intent and conventions. Where reality and this file disagree, fix the code **or** update this file — don't leave them out of sync.

---

## Project summary

MedTrack is a mobile app that lets a user photograph a medicine packet to log it into a personal digital data bank, then reminds them when to take each medicine.

- **Primary users:** the elderly and people managing many daily medications.
- **Scope:** personal-use utility. **No** social, community, feed, or multi-user features.
- **Team:** 2 people. Optimize for small-team velocity — prefer managed services over self-hosted infra.
- **Stage:** early build. A demo/pitch is the near-term target, not a production launch.

The core loop is: **photograph medicine → confirm extracted info → set schedule → get reminder → mark as taken → view history.**

---

## Golden rules (read before writing code)

1. **Elderly-first UX is a hard requirement, not polish.** Large text, high contrast, minimal taps, big unambiguous buttons. The core capture flow (camera → confirm → done) should be ~3 taps. If a change makes the app harder for a non-technical older user, it's wrong.
2. **The "confirm & edit" screen after OCR is mandatory.** OCR/recognition is never assumed correct. Never auto-save a recognized medicine without a user confirmation step.
3. **Always keep a manual fallback.** Every camera/OCR path must have an "add/edit manually" escape hatch. Damaged packets and failed recognition are normal, not edge cases.
4. **Stay in scope.** Do not add social, community, caregiver-sharing, or interaction-checking features (see "Explicitly out of scope"). If a task seems to require one, stop and flag it.
5. **This is health data.** Even though compliance is deferred for the demo, don't log medicine data to third parties, don't put it in analytics events, and don't hardcode it into fixtures that get committed. Treat it as sensitive by default.
6. **Ship testable slices.** Prefer changes that leave the app runnable and demoable. Don't land a half-wired feature that breaks the core loop.

---

## Tech stack

> ⚠️ These reflect the planned direction (see `plan.md` Phase 0). Some may not be locked yet. **Confirm against the actual code before relying on them**, and update this section once Phase 0 decisions are final.

- **App framework:** cross-platform (React Native or Flutter) — single codebase for iOS + Android.
- **Backend / data:** a managed BaaS (Firebase or Supabase) for auth, database, and file storage.
- **Recognition:** cloud OCR / vision service for the demo (e.g., Google Cloud Vision or a vision-capable LLM). On-device ML is explicitly deferred.
- **Drug info:** a public drug database API (e.g., OpenFDA / RxNorm) for the "additional information" feature.

When you introduce or change any of the above, update this file in the same PR.

---

## Commands

> Placeholders until the project is scaffolded in Phase 0. Replace with real commands as soon as they exist — an agent relies on these.

```bash
# Install dependencies
<TODO: e.g. npm install / flutter pub get>

# Run the app locally
<TODO: e.g. npm run ios / npm run android / flutter run>

# Lint
<TODO>

# Test
<TODO>

# Build
<TODO>
```

**Agents:** run lint and tests before considering a task done. If these commands don't exist yet, say so rather than inventing output.

---

## Architecture & data model

The domain is small. Keep it that way.

Core entities:
- **Medicine** — name, dosage, form (pill/liquid/etc.), photo, quantity/supply remaining (optional), notes, optional prescribing doctor.
- **Schedule** — belongs to a Medicine. Frequency/times (e.g. 3×/day, every 8h, specific clock times), plus flags like "with food."
- **DoseEvent / history log** — a record that a scheduled dose was taken / skipped / snoozed / missed, with a timestamp. Drives the adherence history.

Design notes for agents:
- A Medicine can have multiple scheduled times; **overlapping reminder times across different medicines must be bundled** into one notification, not fired as a spammy stack.
- Notification actions ("taken" / "skip" / "snooze") must be actionable from the notification itself, not only inside the app.
- Keep recognition logic (the OCR call + parsing) isolated behind a single service/module so the provider can be swapped without touching UI.

---

## Conventions

- **Naming:** clear over clever. This is a small codebase maintained by 2 people; favor readability.
- **Accessibility:** every interactive element needs an accessible label and a large enough touch target. This is core to the product, not optional.
- **Comments:** explain *why*, not *what*. Flag anything provisional with `// TODO:` or `// HACK:` so it's greppable.
- **Secrets:** never commit API keys (OCR service, drug API, BaaS config). Use env/config files that are gitignored. If you spot a committed secret, stop and flag it.
- **Commits/PRs:** small and scoped to one phase task where possible. Reference the relevant `plan.md` phase.

*(Language-specific style — lint/format rules — to be added once the framework is chosen. Until then, match surrounding code.)*

---

## Explicitly out of scope (do not build)

Flag and stop if a task seems to require any of these — they were deliberately deferred:

- Caregiver / family shared access, and any multi-user account model.
- Medicine **interaction** checking (needs a vetted medical database + liability review).
- Offline / on-device OCR (optimization for much later).
- Any social, community, feed, or sharing feature.
- HIPAA / medical-data compliance work — deferred for the demo, but **must be revisited before any launch with real users' data.** Do not claim the app is compliant.

---

## Working agreement for agents

- If a task is ambiguous or seems to pull you out of scope, ask or flag rather than guessing.
- Don't fabricate command output, test results, or that something works — run it or say you couldn't.
- Prefer the smallest change that satisfies the task and keeps the core loop demoable.
- When you finish, state what you changed, what you ran to verify it, and anything left as a TODO.

---

## When to split this file

Right now one root `AGENTS.md` is correct. Split into nested files **once the code is physically separated**, because nested `AGENTS.md` files let an agent load only the context relevant to the directory it's working in. Concretely:

- When a distinct **backend** (cloud functions / server) directory exists → add `backend/AGENTS.md` covering its runtime, data access rules, and secrets handling.
- When the **mobile app** grows its own build/test tooling worth documenting separately → add `app/AGENTS.md`.
- Keep this root file for cross-cutting rules (the golden rules, scope boundaries, product intent); let nested files hold directory-specific commands and conventions.

Until those directories exist, adding more files just creates duplication — keep everything here.
