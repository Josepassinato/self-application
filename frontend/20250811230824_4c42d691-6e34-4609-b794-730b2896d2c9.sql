-- Create alerts table for observability notifications
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  law_firm_id uuid not null,
  alert_type text not null,
  severity text default 'medium',
  current_value numeric,
  previous_value numeric,
  threshold_exceeded numeric,
  alert_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Enable RLS
alter table public.alerts enable row level security;

-- Policies
create policy "System can insert alerts"
  on public.alerts for insert
  with check (true);

create policy "Users can view alerts for their firm"
  on public.alerts for select
  using (
    law_firm_id in (
      select platform_users.law_firm_id
      from public.platform_users
      where platform_users.auth_user_id = auth.uid()
    )
  );

-- Indexes for performance
create index if not exists idx_alerts_firm_created_at on public.alerts (law_firm_id, created_at desc);
create index if not exists idx_alerts_type on public.alerts (alert_type);
