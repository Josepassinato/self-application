-- Buckets
insert into storage.buckets (id, name, public)
values
  ('uscis_forms', 'uscis_forms', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values
  ('uscis_packages', 'uscis_packages', false)
on conflict (id) do nothing;

-- Storage policies
-- Allow public read of uscis_forms
drop policy if exists "Public can read uscis_forms" on storage.objects;
create policy "Public can read uscis_forms"
on storage.objects for select
using (bucket_id = 'uscis_forms');

-- Authenticated read of uscis_packages constrained to related case via case_forms.output_uri
-- Users in same firm as case responsavel can read
drop policy if exists "Firm users can read generated packages for their cases" on storage.objects;
create policy "Firm users can read generated packages for their cases"
on storage.objects for select
using (
  bucket_id = 'uscis_packages'
  and exists (
    select 1
    from public.case_forms cf
    join public.cases c on c.id = cf.case_id
    join public.clients cl on cl.id = c.client_id
    join public.platform_users pu on pu.auth_user_id = auth.uid()
    where cf.output_uri = 'uscis_packages/' || storage.objects.name
      and pu.law_firm_id in (
        select responsavel.law_firm_id
        from public.platform_users responsavel
        where responsavel.auth_user_id = cl.responsavel_id
      )
  )
);

-- Extend forms_registry
alter table public.forms_registry
  add column if not exists pdf_path text;

-- Ensure not null with default for empty rows
update public.forms_registry set pdf_path = coalesce(pdf_path, '') where pdf_path is null;
-- optional: set to not null if safe
-- alter table public.forms_registry alter column pdf_path set not null;

alter table public.forms_registry
  add column if not exists anchor_map jsonb default '{}'::jsonb;

-- ai_runs table
create table if not exists public.ai_runs (
  id uuid primary key default gen_random_uuid(),
  job_type text not null,
  input_hash text,
  metadata jsonb default '{}'::jsonb,
  artifacts jsonb default '{}'::jsonb,
  duration_ms integer,
  status text default 'success',
  user_id uuid,
  created_at timestamptz not null default now()
);

alter table public.ai_runs enable row level security;

drop policy if exists "System can insert ai runs" on public.ai_runs;
create policy "System can insert ai runs"
on public.ai_runs for insert
with check (true);

drop policy if exists "Users can view their ai runs" on public.ai_runs;
create policy "Users can view their ai runs"
on public.ai_runs for select
using (user_id = auth.uid());
