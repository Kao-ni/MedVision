<div align="center">

<img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Objects/Pill.png" alt="pill" width="100" />
<img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Smilies/Smiling%20Face%20with%20Hearts.png" alt="love" width="100" />
<img src="https://raw.githubusercontent.com/Tarikul-Islam-Anik/Animated-Fluent-Emojis/master/Emojis/Travel%20and%20places/Hospital.png" alt="hospital" width="100" />

# Welcome to MedVision 💊

### Snap a packet, Confirm the details, Never miss a dose!

<br/>

<a href="#-a-little-about-medvision"><img src="https://img.shields.io/badge/iOS-SwiftUI-87CEEB?style=flat-square&logo=apple&logoColor=white" alt="iOS" /></a>
<a href="#-tech-stack"><img src="https://img.shields.io/badge/Swift-FFB6C1?style=flat-square&logo=swift&logoColor=white" alt="Swift" /></a>
<a href="#-tech-stack"><img src="https://img.shields.io/badge/Supabase-98D8C8?style=flat-square&logo=supabase&logoColor=white" alt="Supabase" /></a>
<a href="#-features"><img src="https://img.shields.io/badge/OCR-Typhoon-DDA0DD?style=flat-square&logo=eye&logoColor=white" alt="OCR" /></a>
<img src="https://img.shields.io/badge/status-early%20build-FFEAA7?style=flat-square" alt="Status" />

<br/>
<br/>

📸 Snap &nbsp;→&nbsp; ✏️ Confirm &nbsp;→&nbsp; ⏰ Schedule &nbsp;→&nbsp; 🔔 Remind &nbsp;→&nbsp; ✅ Taken &nbsp;→&nbsp; 📖 History

</div>

<br/>

## 👻 A little about MedVision...

---

**MedVision** is a personal medicine tracking app for iOS — built for the elderly and anyone juggling lots of daily meds.

Photograph a medicine packet, confirm the extracted details, set a schedule, get reminded, and keep a clear history of what was taken, skipped, or missed.

Accessibility-first by design:

🔤 Large text &nbsp;•&nbsp; 🌗 High contrast &nbsp;•&nbsp; 👆 Minimal taps &nbsp;•&nbsp; ✅ Always confirm before saving

> Personal-use only — no social feeds, no caregiver sharing, no clutter.

<br/>

## ✨ Features

---

| | Feature | What it does |
|:---:|:---|:---|
| 📸 | **Packet Recognition** | Capture a packet and extract name, dosage & form via OCR |
| ✅ | **Confirm & Edit** | You review every scan before it saves — nothing is auto-saved |
| ✍️ | **Manual Fallback** | Add or edit meds by hand when a packet is damaged or OCR fails |
| ⏰ | **Scheduling** | Set times & frequency per medicine, including "with food" flags |
| 🔔 | **Smart Reminders** | Local notifications when a dose is due, bundled to avoid spam |
| 📖 | **Dose History** | A timeline of doses taken, skipped, or missed |
| 💡 | **Drug Info** | Look up medicine details through a secure backend proxy |

<br/>

## 🛠️ Tech Stack

---

<div align="center">

<img src="https://img.shields.io/badge/App-SwiftUI%20%2B%20SwiftData-87CEEB?style=for-the-badge&logo=apple&logoColor=white" alt="App" />
<img src="https://img.shields.io/badge/Backend-Supabase-98D8C8?style=for-the-badge&logo=supabase&logoColor=white" alt="Backend" />
<img src="https://img.shields.io/badge/OCR-Typhoon-FFB6C1?style=for-the-badge&logo=eye&logoColor=white" alt="OCR" />
<img src="https://img.shields.io/badge/Drug%20Info-API%20Proxy-DDA0DD?style=for-the-badge&logo=database&logoColor=white" alt="Drug Info" />

<br/><br/>

| Layer | Technology |
|:---:|:---|
| 📱 **App** | Native iOS — SwiftUI, SwiftData |
| ☁️ **Backend** | Supabase — Auth, Postgres, Storage, RLS, Edge Functions |
| 👁️ **Recognition** | Typhoon OCR (proxied through the backend) |
| 💊 **Drug Info** | Public drug database API (proxied through the backend) |

</div>

<br/>

## 🏗️ Architecture

---

- 📱 **iOS app** (`MedVision/`) — SwiftUI interface with local SwiftData persistence. Recognition lives behind a single service, so the OCR provider can be swapped without touching the UI.
- ☁️ **Backend** (`backend/`, `supabase/`) — Supabase owns cloud data, auth, and secrets. Edge Functions proxy OCR and drug-info calls so API keys never reach the client. Every row is protected with Row Level Security 🔒.

### 🧩 Data Model

- 💊 **Medicine** — name, dosage, form, photo, notes
- ⏰ **Schedule** — times and frequency for a medicine
- 📖 **DoseEvent** — a dose taken, skipped, or missed, with a timestamp
- 🔍 **RecognitionJob** — an OCR upload with raw text, parsed result & failure reason

<br/>

## 📂 Project Structure

---

```text
.
├── 📱 MedVision/            # iOS app (SwiftUI)
│   ├── App/                 # Entry point, onboarding, configuration
│   ├── Features/            # Today, Scan, Medicines, History, Profile
│   ├── Models/              # Medicine, DoseEvent, and supporting types
│   └── Services/            # Recognition and notifications
├── 🛠️ MedVision.xcodeproj/  # Xcode project
├── ☁️ backend/               # Shared logic and unit tests
├── 🗄️ supabase/              # Migrations, Edge Functions, config
└── 📚 docs/                  # Specs and implementation plans
```

<br/>

## 🚦 Status

---

🌱 **Early build**, targeting a demo.

The iOS app runs locally with SwiftData while the cloud-backed Supabase backend is being built out.

<br/>

<div align="center">

<img src="https://img.shields.io/badge/Made%20with-💊%20%2B%20💕-FFB6C1?style=for-the-badge" alt="Made with love" />

<br/><br/>

**Built for the people who need it most** 🧓✨

</div>
