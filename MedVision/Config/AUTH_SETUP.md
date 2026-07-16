# Supabase Auth Setup (MedVision)

Complete these steps once so email, Apple, and Google login work on device.

## 1. Create / open a Supabase project

1. Go to https://supabase.com/dashboard
2. Create a project (or open an existing one)
3. Copy **Project URL** and **anon public** key from **Project Settings → API**
4. Paste them into `MedVision/Config/SupabaseSecrets.swift` (gitignored)

## 2. Email provider

1. **Authentication → Providers → Email** → enable
2. For prototype: turn **off** "Confirm email" so signup signs in immediately
3. Keep password requirements reasonable for elderly users (min length is fine)

## 3. Apple provider

1. Apple Developer: enable **Sign in with Apple** for App ID `com.Kao.MedVision`
2. Create a Services ID + key if using web/OAuth flows; for native iOS ID-token flow, configure the Apple provider in Supabase with your Team ID / key as required by the dashboard
3. In Xcode: MedVision target → **Signing & Capabilities** → **Sign in with Apple** (entitlements file is already in the repo)
4. Supabase **Authentication → Providers → Apple** → enable and paste Apple credentials

## 4. Google provider

1. Google Cloud Console: create OAuth client IDs (iOS + Web)
2. Supabase **Authentication → Providers → Google** → enable; paste Client IDs; enable **Skip nonce check** if using native/id-token flows
3. Under **Authentication → URL Configuration**, add redirect:
   - `com.Kao.MedVision://login-callback`
4. The iOS app uses this URL scheme for `signInWithOAuth(.google)`

## 5. Local Supabase (optional)

`supabase/config.toml` already includes the iOS redirect URL for local auth testing.

## 6. Never put in the iOS app

- `service_role` key
- Database passwords
- Typhoon / other third-party secrets (those stay in Edge Function env)

## 7. Smoke test (Developer Mode device)

After filling `SupabaseSecrets.swift` and enabling Email (confirm email off):

1. Cold launch logged out → Auth screen after splash
2. Create account with email/password → enters main tabs
3. Kill app → relaunch → still signed in (Keychain session)
4. Wrong password → readable error on Auth screen
5. Profile shows account email → Sign Out → Auth screen
6. Relaunch after sign out → still logged out
7. Apple / Google only after those providers are configured in the dashboard
