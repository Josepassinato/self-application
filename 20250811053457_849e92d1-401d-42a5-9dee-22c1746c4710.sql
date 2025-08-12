-- Criar tabelas para e-filing assistido
CREATE TABLE IF NOT EXISTS public.efile_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL,
  package_id UUID,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'waiting_handoff', 'failed', 'completed', 'canceled')),
  step TEXT,
  step_index INTEGER DEFAULT 0,
  total_steps INTEGER DEFAULT 0,
  handoff_kind TEXT CHECK (handoff_kind IN ('none', '2fa', 'captcha', 'review', 'payment')),
  handoff_payload JSONB,
  artifacts JSONB DEFAULT '[]'::jsonb,
  logs JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.efile_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_id UUID NOT NULL REFERENCES public.efile_jobs(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('resume', 'pause', 'cancel', 'inject_otp', 'solve_captcha', 'confirm_step')),
  payload JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.efile_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.efile_actions ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
CREATE POLICY "Users can manage efile jobs for their firm" ON public.efile_jobs
FOR ALL USING (
  case_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "Users can manage efile actions for their firm" ON public.efile_actions
FOR ALL USING (
  job_id IN (
    SELECT ej.id FROM public.efile_jobs ej
    WHERE ej.case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
      WHERE pu.law_firm_id IN (
        SELECT resp.law_firm_id FROM public.platform_users resp 
        WHERE resp.auth_user_id = cl.responsavel_id
      )
    )
  )
);

-- Trigger para updated_at
CREATE TRIGGER update_efile_jobs_updated_at
  BEFORE UPDATE ON public.efile_jobs
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_efile_jobs_status ON public.efile_jobs(status);
CREATE INDEX IF NOT EXISTS idx_efile_jobs_case_id ON public.efile_jobs(case_id);
CREATE INDEX IF NOT EXISTS idx_efile_actions_job_id ON public.efile_actions(job_id);