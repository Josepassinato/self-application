-- Create e-filing accounts table
CREATE TABLE IF NOT EXISTS public.efiling_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL REFERENCES public.platform_users(id) ON DELETE CASCADE,
  service TEXT NOT NULL DEFAULT 'uscis',
  username TEXT NOT NULL,
  password TEXT NOT NULL, -- Will be encrypted at application level
  mfa_secret TEXT, -- Will be encrypted at application level
  created_at TIMESTAMPTZ DEFAULT now(),
  last_login TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Create e-filing logs table
CREATE TABLE IF NOT EXISTS public.efiling_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  account_id UUID NOT NULL REFERENCES public.efiling_accounts(id) ON DELETE CASCADE,
  step TEXT NOT NULL,
  status TEXT NOT NULL, -- 'pending', 'in_progress', 'completed', 'failed'
  message TEXT,
  screenshot_url TEXT,
  execution_time_ms INTEGER,
  created_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Create case events table
CREATE TABLE IF NOT EXISTS public.case_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL, -- 'biometrics_appointment', 'interview_notice', 'decision', etc.
  event_date TIMESTAMPTZ,
  location TEXT,
  description TEXT,
  receipt_number TEXT,
  document_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  notified_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE public.efiling_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.efiling_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_events ENABLE ROW LEVEL SECURITY;

-- RLS Policies for efiling_accounts
CREATE POLICY "Partners can manage their e-filing accounts"
ON public.efiling_accounts
FOR ALL
USING (
  partner_id IN (
    SELECT pu.id 
    FROM public.platform_users pu 
    WHERE pu.auth_user_id = auth.uid()
      AND pu.role IN ('partner', 'admin')
  )
);

-- RLS Policies for efiling_logs
CREATE POLICY "Users can view e-filing logs for their firm cases"
ON public.efiling_logs
FOR SELECT
USING (
  case_id IN (
    SELECT c.id
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage e-filing logs"
ON public.efiling_logs
FOR ALL
USING (true);

-- RLS Policies for case_events
CREATE POLICY "Users can view case events for their firm cases"
ON public.case_events
FOR SELECT
USING (
  case_id IN (
    SELECT c.id
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage case events"
ON public.case_events
FOR ALL
USING (true);

-- Indexes for performance
CREATE INDEX idx_efiling_accounts_partner_id ON public.efiling_accounts(partner_id);
CREATE INDEX idx_efiling_accounts_service ON public.efiling_accounts(service);
CREATE INDEX idx_efiling_logs_case_id ON public.efiling_logs(case_id);
CREATE INDEX idx_efiling_logs_account_id ON public.efiling_logs(account_id);
CREATE INDEX idx_case_events_case_id ON public.case_events(case_id);
CREATE INDEX idx_case_events_event_type ON public.case_events(event_type);
CREATE INDEX idx_case_events_event_date ON public.case_events(event_date);