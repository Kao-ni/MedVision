# MedVision Backend

This directory contains local-testable backend logic that supports the Supabase deployment under `../supabase`.

## Layout

- `src/` shared parsing, validation, contract, and normalization modules
- `tests/` Node tests for shared logic
- `../supabase/functions/` deployable Edge Functions
- `../supabase/migrations/` schema, storage, and RLS migrations

## Local commands

```bash
npm --prefix backend test
```

## Deployment prerequisites

- Supabase project created
- `TYPHOON_API_KEY` configured in Supabase secrets
- `DRUG_INFO_PROVIDER` and any provider key configured in Supabase secrets
- Supabase CLI installed on the deployment machine
