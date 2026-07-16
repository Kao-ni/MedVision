# LINE caregiver missed-dose alerts

Grandma uses MedVision signed-in. If a dose stays `pending` for **30 minutes**, cron marks it `missed` and sends **one** LINE push to the linked caregiver.

## Prerequisites

1. LINE Developers: create a Messaging API channel (Official Account).
2. Supabase Edge Function secrets:

```bash
supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=...
supabase secrets set LINE_CHANNEL_SECRET=...
supabase secrets set CRON_SECRET=...   # optional but recommended
```

3. Apply migration:

```bash
supabase db push
# or run supabase/migrations/20260716140000_line_caregiver_alerts.sql in the SQL editor
```

4. Deploy functions:

```bash
supabase functions deploy dose-events --project-ref neehwqyjieairigtgrzo
supabase functions deploy caregiver-invite --project-ref neehwqyjieairigtgrzo
supabase functions deploy line-webhook --project-ref neehwqyjieairigtgrzo
supabase functions deploy missed-dose-check --project-ref neehwqyjieairigtgrzo
```

5. LINE webhook URL:

`https://neehwqyjieairigtgrzo.supabase.co/functions/v1/line-webhook`

Enable webhook in LINE console. Use channel secret verification (no JWT) — if Supabase requires a JWT on functions, set the function to verify JWT **off** for `line-webhook` only (Dashboard → Edge Functions → line-webhook → Enforce JWT = off).

## Cron

Schedule every 5 minutes (Supabase Dashboard → Edge Functions → Schedules, or external cron):

```bash
curl -X POST "https://neehwqyjieairigtgrzo.supabase.co/functions/v1/missed-dose-check" \
  -H "Authorization: Bearer $CRON_SECRET" \
  -H "apikey: $SUPABASE_ANON_KEY"
```

## Patient setup (in app)

1. Sign in (not guest).
2. Profile → **Caregiver LINE alerts** → Generate invite code.
3. Caregiver adds the OA in LINE and sends the 8-character code.
4. App shows **Caregiver connected**. Unlink anytime to stop alerts.

## Manual verify

```bash
node backend/scripts/verify-line-missed-dose.mjs
```

(Uses mocked helpers when secrets are absent; live checks when env is set.)

## Privacy

LINE messages include patient display name, medicine name, dosage, and scheduled time only — never label photos or OCR text.
