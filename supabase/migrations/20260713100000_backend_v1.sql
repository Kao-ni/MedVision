create extension if not exists pgcrypto;

create type public.medicine_form as enum (
  'pill',
  'liquid',
  'injection',
  'patch',
  'inhaler',
  'other'
);

create type public.medicine_source as enum (
  'manual',
  'ocr'
);

create type public.dose_event_status as enum (
  'pending',
  'complete',
  'omitted',
  'missed'
);

create type public.recognition_status as enum (
  'queued',
  'processing',
  'completed',
  'failed'
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.medicines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  dosage text not null default '',
  form public.medicine_form not null default 'pill',
  notes text not null default '',
  image_path text,
  source public.medicine_source not null default 'manual',
  frequency_note text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  medicine_id uuid not null references public.medicines(id) on delete cascade,
  frequency_type text not null check (char_length(trim(frequency_type)) > 0),
  times jsonb not null default '[]'::jsonb,
  with_food boolean not null default false,
  instructions text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint schedules_times_is_array check (jsonb_typeof(times) = 'array')
);

create table if not exists public.dose_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  medicine_id uuid not null references public.medicines(id) on delete cascade,
  scheduled_for timestamptz not null,
  taken_at timestamptz,
  status public.dose_event_status not null default 'pending',
  created_at timestamptz not null default timezone('utc', now()),
  constraint dose_events_taken_at_required_for_complete check (
    status <> 'complete' or taken_at is not null
  )
);

create table if not exists public.recognition_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  image_path text not null,
  status public.recognition_status not null default 'queued',
  raw_ocr_text text not null default '',
  parsed_result jsonb,
  failure_reason text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.drug_info_cache (
  id uuid primary key default gen_random_uuid(),
  normalized_query text not null unique,
  provider text not null,
  response_summary jsonb not null,
  fetched_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null
);

create index if not exists medicines_user_id_idx on public.medicines(user_id);
create index if not exists schedules_user_id_idx on public.schedules(user_id);
create index if not exists schedules_medicine_id_idx on public.schedules(medicine_id);
create index if not exists dose_events_user_id_idx on public.dose_events(user_id);
create index if not exists dose_events_medicine_id_idx on public.dose_events(medicine_id);
create index if not exists dose_events_scheduled_for_idx on public.dose_events(scheduled_for desc);
create index if not exists recognition_jobs_user_id_idx on public.recognition_jobs(user_id);
create index if not exists recognition_jobs_status_idx on public.recognition_jobs(status);
create index if not exists drug_info_cache_expires_at_idx on public.drug_info_cache(expires_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists medicines_set_updated_at on public.medicines;
create trigger medicines_set_updated_at
before update on public.medicines
for each row
execute function public.set_updated_at();

drop trigger if exists schedules_set_updated_at on public.schedules;
create trigger schedules_set_updated_at
before update on public.schedules
for each row
execute function public.set_updated_at();

drop trigger if exists recognition_jobs_set_updated_at on public.recognition_jobs;
create trigger recognition_jobs_set_updated_at
before update on public.recognition_jobs
for each row
execute function public.set_updated_at();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.medicines enable row level security;
alter table public.schedules enable row level security;
alter table public.dose_events enable row level security;
alter table public.recognition_jobs enable row level security;
alter table public.drug_info_cache enable row level security;

create policy "profiles_select_own"
  on public.profiles
  for select
  using (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "medicines_select_own"
  on public.medicines
  for select
  using (auth.uid() = user_id);

create policy "medicines_insert_own"
  on public.medicines
  for insert
  with check (auth.uid() = user_id);

create policy "medicines_update_own"
  on public.medicines
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "medicines_delete_own"
  on public.medicines
  for delete
  using (auth.uid() = user_id);

create policy "schedules_select_own"
  on public.schedules
  for select
  using (auth.uid() = user_id);

create policy "schedules_insert_own"
  on public.schedules
  for insert
  with check (auth.uid() = user_id);

create policy "schedules_update_own"
  on public.schedules
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "schedules_delete_own"
  on public.schedules
  for delete
  using (auth.uid() = user_id);

create policy "dose_events_select_own"
  on public.dose_events
  for select
  using (auth.uid() = user_id);

create policy "dose_events_insert_own"
  on public.dose_events
  for insert
  with check (auth.uid() = user_id);

create policy "dose_events_update_own"
  on public.dose_events
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "dose_events_delete_own"
  on public.dose_events
  for delete
  using (auth.uid() = user_id);

create policy "recognition_jobs_select_own"
  on public.recognition_jobs
  for select
  using (auth.uid() = user_id);

create policy "recognition_jobs_insert_own"
  on public.recognition_jobs
  for insert
  with check (auth.uid() = user_id);

create policy "recognition_jobs_update_own"
  on public.recognition_jobs
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "recognition_jobs_delete_own"
  on public.recognition_jobs
  for delete
  using (auth.uid() = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'medicine-images',
  'medicine-images',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "storage_select_own_medicine_images"
  on storage.objects
  for select
  using (
    bucket_id = 'medicine-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "storage_insert_own_medicine_images"
  on storage.objects
  for insert
  with check (
    bucket_id = 'medicine-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "storage_update_own_medicine_images"
  on storage.objects
  for update
  using (
    bucket_id = 'medicine-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  )
  with check (
    bucket_id = 'medicine-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "storage_delete_own_medicine_images"
  on storage.objects
  for delete
  using (
    bucket_id = 'medicine-images'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
