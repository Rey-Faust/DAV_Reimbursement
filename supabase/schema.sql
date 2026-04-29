create table if not exists public.reimbursements (
  id bigint generated always as identity primary key,
  expense_date date not null,
  expense_type text not null check (char_length(trim(expense_type)) > 0),
  project_name text not null check (char_length(trim(project_name)) > 0),
  amount_lkr numeric(12, 2) not null check (amount_lkr >= 0),
  currency_code text not null default 'LKR',
  amount_original numeric(12, 2),
  exchange_rate_to_lkr numeric(16, 6) not null default 1,
  fx_lkr_to_php numeric(16, 8),
  fx_lkr_to_cny numeric(16, 8),
  fx_lkr_to_usd numeric(16, 8),
  fx_locked_at timestamptz,
  reimburser text,
  status text not null default '待报销',
  image_path text,
  image_url text,
  image_paths jsonb not null default '[]'::jsonb,
  image_urls jsonb not null default '[]'::jsonb,
  owner_id uuid not null default auth.uid(),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.reimbursements
  add column if not exists reimburser text;

alter table public.reimbursements
  add column if not exists status text not null default '待报销';

alter table public.reimbursements
  alter column status set default '待报销';

alter table public.reimbursements
  add column if not exists currency_code text not null default 'LKR';

alter table public.reimbursements
  add column if not exists amount_original numeric(12, 2);

alter table public.reimbursements
  add column if not exists exchange_rate_to_lkr numeric(16, 6) not null default 1;

alter table public.reimbursements
  add column if not exists fx_lkr_to_php numeric(16, 8);

alter table public.reimbursements
  add column if not exists fx_lkr_to_cny numeric(16, 8);

alter table public.reimbursements
  add column if not exists fx_lkr_to_usd numeric(16, 8);

alter table public.reimbursements
  add column if not exists fx_locked_at timestamptz;

alter table public.reimbursements
  add column if not exists image_paths jsonb not null default '[]'::jsonb;

alter table public.reimbursements
  add column if not exists image_urls jsonb not null default '[]'::jsonb;

alter table public.reimbursements
  add column if not exists owner_id uuid;

alter table public.reimbursements
  alter column owner_id set default auth.uid();

alter table public.reimbursements
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.reimbursements
  alter column updated_at set default timezone('utc', now());

update public.reimbursements
set updated_at = coalesce(updated_at, created_at, timezone('utc', now()))
where updated_at is null;

update public.reimbursements
set image_paths = jsonb_build_array(image_path)
where image_path is not null
  and image_path <> ''
  and (image_paths is null or image_paths = '[]'::jsonb);

update public.reimbursements
set image_urls = jsonb_build_array(image_url)
where image_url is not null
  and image_url <> ''
  and (image_urls is null or image_urls = '[]'::jsonb);

update public.reimbursements
set amount_original = amount_lkr
where (amount_original is null or amount_original <= 0)
  and amount_lkr is not null;

update public.reimbursements
set exchange_rate_to_lkr = 1
where exchange_rate_to_lkr is null or exchange_rate_to_lkr <= 0;

update public.reimbursements
set fx_lkr_to_php = round((1 / exchange_rate_to_lkr)::numeric, 8)
where fx_lkr_to_php is null
  and currency_code = 'PHP'
  and exchange_rate_to_lkr is not null
  and exchange_rate_to_lkr > 0;

update public.reimbursements
set fx_lkr_to_cny = round((1 / exchange_rate_to_lkr)::numeric, 8)
where fx_lkr_to_cny is null
  and currency_code = 'CNY'
  and exchange_rate_to_lkr is not null
  and exchange_rate_to_lkr > 0;

update public.reimbursements
set fx_lkr_to_usd = round((1 / exchange_rate_to_lkr)::numeric, 8)
where fx_lkr_to_usd is null
  and currency_code = 'USD'
  and exchange_rate_to_lkr is not null
  and exchange_rate_to_lkr > 0;

update public.reimbursements
set fx_locked_at = coalesce(fx_locked_at, created_at, timezone('utc', now()))
where fx_locked_at is null;

update public.reimbursements
set currency_code = 'LKR'
where currency_code is null or char_length(trim(currency_code)) = 0;

update public.reimbursements
set status = '待报销'
where status is null
   or status not in ('待报销', '已报销');

create index if not exists reimbursements_owner_date_id_idx
  on public.reimbursements (owner_id, expense_date desc, id desc);

create index if not exists reimbursements_owner_updated_at_idx
  on public.reimbursements (owner_id, updated_at desc);

drop trigger if exists reimbursements_set_updated_at on public.reimbursements;
drop function if exists public.set_reimbursements_updated_at();
create function public.set_reimbursements_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create trigger reimbursements_set_updated_at
before update on public.reimbursements
for each row
execute function public.set_reimbursements_updated_at();

alter table public.reimbursements enable row level security;

drop policy if exists "Public can read reimbursements" on public.reimbursements;
drop policy if exists "Public can insert reimbursements" on public.reimbursements;
drop policy if exists "Public can update reimbursements" on public.reimbursements;
drop policy if exists "Public can delete reimbursements" on public.reimbursements;
drop policy if exists "Authenticated users can read own reimbursements" on public.reimbursements;
drop policy if exists "Authenticated users can insert own reimbursements" on public.reimbursements;
drop policy if exists "Authenticated users can update own reimbursements" on public.reimbursements;
drop policy if exists "Authenticated users can delete own reimbursements" on public.reimbursements;

create policy "Public can read reimbursements"
on public.reimbursements
for select
to public
using (true);

create policy "Authenticated users can insert own reimbursements"
on public.reimbursements
for insert
to authenticated
with check (owner_id = auth.uid());

create policy "Authenticated users can update own reimbursements"
on public.reimbursements
for update
to authenticated
using (owner_id = auth.uid() or owner_id is null)
with check (owner_id = auth.uid());

create policy "Authenticated users can delete own reimbursements"
on public.reimbursements
for delete
to authenticated
using (owner_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'reimbursement-images',
  'reimbursement-images',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp', 'image/heic']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view reimbursement images" on storage.objects;
drop policy if exists "Public can upload reimbursement images" on storage.objects;
drop policy if exists "Public can delete reimbursement images" on storage.objects;
drop policy if exists "Authenticated users can view own reimbursement images" on storage.objects;
drop policy if exists "Authenticated users can upload own reimbursement images" on storage.objects;
drop policy if exists "Authenticated users can delete own reimbursement images" on storage.objects;

create policy "Public can view reimbursement images"
on storage.objects
for select
to public
using (bucket_id = 'reimbursement-images');

create policy "Authenticated users can upload own reimbursement images"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'reimbursement-images' and owner = auth.uid());

create policy "Authenticated users can delete own reimbursement images"
on storage.objects
for delete
to authenticated
using (bucket_id = 'reimbursement-images' and owner = auth.uid());
