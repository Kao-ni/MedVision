alter type public.medicine_form add value if not exists 'tablet';
alter type public.medicine_form add value if not exists 'capsule';

alter table public.medicines
  add column if not exists barcode text;

alter table public.medicines
  alter column form set default 'tablet';

create index if not exists medicines_user_barcode_idx
  on public.medicines(user_id, barcode);
