# MedTrack — Personal Medicine Manager
### Execution Plan

**What it is:** A mobile app that lets users photograph a medicine packet to log it into a digital data bank, then reminds them when to take it. Built for elderly users and people managing multiple daily medications. Personal-use only (no social/community features), team of 2.

**Guiding principles for every phase:**
- Ship something testable at the end of each phase — don't wait until the end to see it work.
- Elderly-first UX: large text, high contrast, minimal taps, big obvious buttons.
- Defer anything related to medical liability, interactions, or shared/caregiver access until after the core loop works.

---

## Phase 0 — Setup & Decisions (1–2 days)

**Goal:** Remove blockers before writing feature code.

- [x] **Platform: native iOS, Swift + SwiftUI.** (Decided.) Single-platform for now — Android is deferred, not part of this build.
- [x] **OCR: Typhoon OCR** (SCB 10X), reached over its hosted API. (Decided.) Key facts that shape the build:
  - It's a **vision-language model accessed over an API** (`api.opentyphoon.ai/v1`, OpenAI-compatible), **not** an on-device iOS library. On-device on an iPhone is not viable — it's a multi-billion-parameter model needing a GPU (via vLLM) to self-host. So recognition is **cloud/API-based** for this app. (This resolves the earlier "offline vs cloud" question.)
  - It's **Thai/English bilingual** — a strong fit if packets are in Thai, better than generic OCR.
  - It returns **structured Markdown/text of the packet**, not a clean `{name, dosage}` object. A parsing step (Markdown → structured medicine fields) is required after OCR — see Phase 2.
  - **Do NOT ship the Typhoon API key inside the app binary** (it can be extracted). Decide now between:
    - (a) **Thin backend proxy** (recommended beyond a throwaway demo): app → your backend → Typhoon. Keeps the key server-side, and gives you a natural home for the Markdown→structured parsing step.
    - (b) **Direct app → Typhoon API** (fastest, key exposed): acceptable only for a local, non-distributed demo. Plan to move to (a) before sharing the build.
- [ ] Decide drug info data source for "additional information" feature (e.g., OpenFDA API, RxNorm) — confirm it has a free/dev tier and note it may be English-only if packets are Thai
- [ ] Get a Typhoon API key (opentyphoon.ai) and confirm free/dev tier limits are enough for testing
- [ ] Set up Xcode project + repo, and basic CI (build + lint check, e.g. SwiftLint)
- [ ] Set up data/storage choice (e.g., local Core Data / SwiftData for a pure-personal app, or Firebase/Supabase if you want cloud sync + hosted backend — both have Swift SDKs and can double as the proxy backend)
- [ ] Assign rough ownership between the 2 team members (e.g., one on SwiftUI/app, one on OCR integration + backend proxy) — this can shift, but avoids stepping on each other early

**Exit criteria:** Repo exists, both people can run the app locally, tech choices are written down (not just decided verbally).

---

## Phase 1 — Manual Core Loop (No OCR Yet) (1 week)

**Goal:** Prove the core loop end-to-end using manual data entry, before adding the hard part (OCR). This de-risks the reminder system early.

- [ ] Basic app shell with 3 screens: Medicine List → Add/Edit Medicine → Reminder Settings
- [ ] Manual "Add Medicine" form: name, dosage, form (pill/liquid/etc.), photo upload (just stores the photo, no recognition yet)
- [ ] Medicine data bank: local/cloud storage of medicine records, list view
- [ ] Schedule builder: set frequency (e.g., 3x daily, every 8 hrs, specific times, "with food" note)
- [ ] Push notification setup (device permissions + basic scheduled local notifications)
- [ ] Reminder fires at the right time with medicine name + dosage shown
- [ ] "Mark as taken" / "skip" / "snooze" actions directly from the notification

**Exit criteria:** You can manually add a medicine, set a schedule, and get a real notification on your phone that you can act on. This is a demoable app even without OCR.

---

## Phase 2 — Photo Recognition (1–2 weeks)

**Goal:** Replace manual entry with the camera-first flow — your key differentiator.

- [ ] Camera capture screen (take photo or pick from gallery), using SwiftUI + `PhotosPicker` / `AVFoundation`
- [ ] **Step 1 — OCR:** send the image to Typhoon (via your proxy from Phase 0). Typhoon returns structured **Markdown/text** of the packet — this is raw packet text, not yet a medicine record.
- [ ] **Step 2 — Extract fields:** parse the Markdown into `{ name, dosage, form }`. Start simple (string/keyword parsing); if packets are messy, a light second LLM call to structure the text is a reasonable upgrade. Keep this logic in one isolated module so it's easy to tune.
- [ ] **"Confirm & Edit" screen** — show extracted fields, let the user correct them before saving. **Mandatory:** OCR + parsing will not be 100% accurate, especially on foil/curved packets.
- [ ] Fallback path: "Can't read this? Add manually" always available (and shown automatically if OCR fails or returns nothing usable)
- [ ] Handle API failure states gracefully (no internet, timeout, key/quota error) — never leave the user stuck on a spinner
- [ ] Save confirmed medicine into the same data bank from Phase 1

**Exit criteria:** User can photograph a real medicine packet, see extracted info, correct it if needed, and it becomes a tracked medicine with reminders — full core loop closed.

---

## Phase 3 — Elderly-First UX Pass (3–5 days)

**Goal:** This is the feature, not polish — revisit before wide testing.

- [ ] Increase base font size and contrast app-wide; test on an actual older user if possible
- [ ] Reduce core flow to as few taps as possible (camera → confirm → done should be 3 taps, not 8)
- [ ] Make notification action buttons large and unambiguous ("Yes, I took it" vs. a small checkbox)
- [ ] Evaluate voice input as an alternative to typing corrections (stretch goal — timebox this, don't let it block the phase)
- [ ] Simplify navigation to avoid nested menus

**Exit criteria:** A non-technical elderly test user (ideally your grandma) can complete the full loop without help.

---

## Phase 4 — History & Additional Info (1 week)

**Goal:** Add the two secondary features you identified.

- [ ] Adherence history log: simple list/calendar of what was taken, skipped, or missed, per medicine
- [ ] Integrate drug info API: show general info (what it's for, common side effects) on a medicine's detail screen
- [ ] Handle "info not found" gracefully (not every OCR result will match a database entry)

**Exit criteria:** Every medicine has a detail screen showing history + general info, not just a name and schedule.

---

## Phase 5 — Demo Readiness & Hardening (3–5 days)

**Goal:** Make it presentable and stable for a demo/pitch, without over-building.

- [ ] Handle edge cases: multiple medicines with overlapping reminder times (bundle notifications, don't spam)
- [ ] Empty states (no medicines yet), error states (OCR failed, no internet)
- [ ] Basic onboarding screen explaining the app in one sentence
- [ ] App icon, name, basic branding
- [ ] Test on both iOS and Android if using cross-platform framework
- [ ] Prepare a short demo script: camera capture → confirm → reminder fires → mark as taken → view history

**Exit criteria:** You can hand the app to someone unfamiliar with it and they understand and use it within a minute, no explanation needed.

---

## Explicitly deferred (do not build yet)

These came up in planning but are intentionally out of scope until the core app is validated:

- Caregiver/family shared access (adds accounts, permissions, privacy — real complexity)
- Medicine interaction checking (needs a real medical database + liability consideration)
- Offline/on-device OCR (optimization, not a v1 requirement)
- Any social or community features
- HIPAA/medical data compliance (you noted: not needed for demo, but flag before any real launch with real user data)

---

## Suggested immediate next step

Start **Phase 0** today: lock in the platform + OCR approach, since every later phase depends on those two decisions.
