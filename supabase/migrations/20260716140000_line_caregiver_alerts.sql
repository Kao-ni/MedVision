-- LINE caregiver missed-dose alerts
-- Grace period is enforced in missed-dose-check (30 minutes).

alter table public.dose_events
  add column if not exists alert_sent_at timestamptz,
  add column if not exists alert_attempts integer not null default 0,
  add column if not exists client_key text;

create unique index if not exists dose_events_user_client_key_uidx
  on public.dose_events (user_id, client_key)
  where client_key is not null;

create index if not exists dose_events_missed_check_idx
  on public.dose_events (status, scheduled_for)
  where status = 'pending' and alert_sent_at is null;

alter table public.profiles
  add column if not exists display_name text not null default '';

create table if not exists public.caregiver_line_links (
  id uuid primary key default gen_random_uuid(),
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  line_user_id text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  constraint caregiver_line_links_line_user_id_nonempty check (char_length(trim(line_user_id)) > 0)
);

create unique index if not exists caregiver_line_links_patient_uidx
  on public.caregiver_line_links (patient_user_id)
  where revoked_at is null;

create index if not exists caregiver_line_links_line_user_idx
  on public.caregiver_line_links (line_user_id);

create table if not exists public.caregiver_invite_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  patient_user_id uuid not null references public.profiles(id) on delete cascade,
  expires_at timestamptz not null,
  used_at timestamptz,
  used_by_line_user_id text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint caregiver_invite_codes_code_format check (code ~ '^[A-Z0-9]{8}$')
);

create unique index if not exists caregiver_invite_codes_code_uidx
  on public.caregiver_invite_codes (code);

create index if not exists caregiver_invite_codes_patient_idx
  on public.caregiver_invite_codes (patient_user_id);

alter table public.caregiver_line_links enable row level security;
alter table public.caregiver_invite_codes enable row level security;

create policy "caregiver_line_links_select_own"
  on public.caregiver_line_links
  for select
  using (auth.uid() = patient_user_id);

create policy "caregiver_line_links_update_own"
  on public.caregiver_line_links
  for update
  using (auth.uid() = patient_user_id)
  with check (auth.uid() = patient_user_id);

create policy "caregiver_line_links_insert_own"
  on public.caregiver_line_links
  for insert
  with check (auth.uid() = patient_user_id);

create policy "caregiver_invite_codes_select_own"
  on public.caregiver_invite_codes
  for select
  using (auth.uid() = patient_user_id);

create policy "caregiver_invite_codes_insert_own"
  on public.caregiver_invite_codes
  for insert
  with check (auth.uid() = patient_user_id);
