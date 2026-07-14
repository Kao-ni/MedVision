# MedVision

MedVision is a personal medicine tracking app for iOS. A user photographs a medicine packet, confirms the extracted details, sets a schedule, and gets reminders to take each dose — with a full history of what was taken, skipped, or missed.

Built for the elderly and people managing many daily medications, with an accessibility-first interface: large text, high contrast, minimal taps, and a mandatory confirmation step after recognition. MedVision is a personal-use utility — no social, caregiver-sharing, or multi-user features.

## Core loop

Photograph medicine → confirm & edit details → set schedule → get reminders → mark as taken → view history.

## Features

- **Packet recognition** — Capture a medicine packet and extract name, dosage, and form via OCR.
- **Confirm & edit** — Every recognition is reviewed and corrected by the user before it is saved; nothing is auto-saved.
- **Manual entry fallback** — Add or edit any medicine by hand for damaged packets or failed scans.
- **Scheduling** — Set times and frequency per medicine, including flags such as "with food."
- **Reminders** — Local notifications when a dose is due, with overlapping times bundled to avoid spam.
- **Dose history** — A running log of doses taken, skipped, or missed with timestamps.
- **Drug information** — Look up details for a medicine through a backend-proxied drug database.

## Tech stack

| Layer | Technology |
| --- | --- |
| App | Native iOS — SwiftUI, SwiftData |
| Backend | Supabase — Auth, Postgres, Storage, Row Level Security, Edge Functions |
| Recognition | Typhoon OCR (proxied through the backend) |
| Drug info | Public drug database API (proxied through the backend) |

## Architecture

- **iOS app** (`MedVision/`) — SwiftUI interface and local SwiftData persistence. Recognition is isolated behind a single service so the OCR provider can be swapped without touching the UI.
- **Backend** (`backend/`, `supabase/`) — Supabase owns cloud data, authentication, and secrets. Edge Functions proxy OCR and drug-info requests so third-party API keys never reach the client. All user data is protected with Row Level Security.

### Data model

- **Medicine** — name, dosage, form, photo, notes.
- **Schedule** — times and frequency for a medicine.
- **DoseEvent** — a dose taken, skipped, or missed, with a timestamp.
- **RecognitionJob** — an OCR upload with raw text, parsed result, and failure reason.

## Project structure

```
MedVision-main/
├── MedVision/            # iOS app (SwiftUI)
│   ├── App/              # Entry point, onboarding, configuration
│   ├── Features/         # Today, Scan, Medicines, History, Profile
│   ├── Models/           # Medicine, DoseEvent, and supporting types
│   └── Services/         # Recognition and notifications
├── MedVision.xcodeproj/  # Xcode project
├── backend/              # Shared logic and unit tests
├── supabase/             # Migrations, Edge Functions, config
└── docs/                 # Specs and implementation plans
```

## Status

Early build, targeting a demo. The iOS app runs locally with SwiftData while the cloud-backed Supabase backend is being built out.
