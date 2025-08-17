-- CRM/Funnel schema with RLS per law_firm_id and automation hooks
BEGIN;

-- 1) Tables ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.crm_pipelines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  pipeline_id UUID NOT NULL REFERENCES public.crm_pipelines(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  probability INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_won BOOLEAN NOT NULL DEFAULT false,
  is_lost BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  pipeline_id UUID NOT NULL REFERENCES public.crm_pipelines(id) ON DELETE SET NULL,
  current_stage_id UUID REFERENCES public.crm_stages(id) ON DELETE SET NULL,
  assigned_to UUID,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  source TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'open', -- open, won, lost
  company TEXT,
  value NUMERIC NOT NULL DEFAULT 0,
  expected_close_date DATE,
  notes TEXT,
  last_activity_at TIMESTAMPTZ,
  stage_entered_at TIMESTAMPTZ,
  converted_case_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  lead_id UUID NOT NULL REFERENCES public.crm_leads(id) ON DELETE CASCADE,
  type TEXT NOT NULL, -- call, email, task, note, meeting
  title TEXT NOT NULL,
  description TEXT,
  due_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_automations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  trigger_event TEXT NOT NULL, -- on_stage_change, on_lead_created
  trigger_stage_id UUID REFERENCES public.crm_stages(id) ON DELETE SET NULL,
  pipeline_id UUID REFERENCES public.crm_pipelines(id) ON DELETE SET NULL,
  conditions JSONB NOT NULL DEFAULT '{}',
  actions JSONB NOT NULL, -- e.g. [{"type":"send_email","template":"intake"},{"type":"create_task","title":"...","due_in_days":2}]
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_lead_stage_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  lead_id UUID NOT NULL REFERENCES public.crm_leads(id) ON DELETE CASCADE,
  from_stage_id UUID,
  to_stage_id UUID,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by UUID,
  duration_seconds INTEGER
);

-- 2) Indexes --------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_crm_pipelines_firm ON public.crm_pipelines(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_crm_stages_pipeline ON public.crm_stages(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_crm_stages_firm ON public.crm_stages(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_firm ON public.crm_leads(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_pipeline ON public.crm_leads(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_stage ON public.crm_leads(current_stage_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_source ON public.crm_leads(source);
CREATE INDEX IF NOT EXISTS idx_crm_leads_tags ON public.crm_leads USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_crm_activities_lead ON public.crm_activities(lead_id);
CREATE INDEX IF NOT EXISTS idx_crm_automations_stage ON public.crm_automations(trigger_stage_id);

-- 3) RLS Policies ---------------------------------------------------------
ALTER TABLE public.crm_pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_automations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_lead_stage_history ENABLE ROW LEVEL SECURITY;

-- Helper predicate for firm scoping
CREATE POLICY IF NOT EXISTS "CRM: users can view pipelines in firm" ON public.crm_pipelines
  FOR SELECT USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));
CREATE POLICY IF NOT EXISTS "CRM: users can manage pipelines in firm" ON public.crm_pipelines
  FOR ALL USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  )) WITH CHECK (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));

CREATE POLICY IF NOT EXISTS "CRM: users can view stages in firm" ON public.crm_stages
  FOR SELECT USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));
CREATE POLICY IF NOT EXISTS "CRM: users can manage stages in firm" ON public.crm_stages
  FOR ALL USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  )) WITH CHECK (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));

CREATE POLICY IF NOT EXISTS "CRM: users can view leads in firm" ON public.crm_leads
  FOR SELECT USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));
CREATE POLICY IF NOT EXISTS "CRM: users can manage leads in firm" ON public.crm_leads
  FOR ALL USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  )) WITH CHECK (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));

CREATE POLICY IF NOT EXISTS "CRM: users can view activities in firm" ON public.crm_activities
  FOR SELECT USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));
CREATE POLICY IF NOT EXISTS "CRM: users can manage activities in firm" ON public.crm_activities
  FOR ALL USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  )) WITH CHECK (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));

CREATE POLICY IF NOT EXISTS "CRM: users can view automations in firm" ON public.crm_automations
  FOR SELECT USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));
CREATE POLICY IF NOT EXISTS "CRM: users can manage automations in firm" ON public.crm_automations
  FOR ALL USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  )) WITH CHECK (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));

CREATE POLICY IF NOT EXISTS "CRM: users can view stage history in firm" ON public.crm_lead_stage_history
  FOR SELECT USING (law_firm_id IN (
    SELECT platform_users.law_firm_id FROM public.platform_users WHERE platform_users.auth_user_id = auth.uid()
  ));
CREATE POLICY IF NOT EXISTS "CRM: system can insert stage history" ON public.crm_lead_stage_history
  FOR INSERT WITH CHECK (true);

-- 4) Triggers & functions --------------------------------------------------
-- update timestamps via existing function
CREATE TRIGGER trg_crm_pipelines_updated_at
  BEFORE UPDATE ON public.crm_pipelines
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_crm_stages_updated_at
  BEFORE UPDATE ON public.crm_stages
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_crm_leads_updated_at
  BEFORE UPDATE ON public.crm_leads
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_crm_activities_updated_at
  BEFORE UPDATE ON public.crm_activities
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trg_crm_automations_updated_at
  BEFORE UPDATE ON public.crm_automations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- When a new activity is created, bump the lead.last_activity_at
CREATE OR REPLACE FUNCTION public.crm_touch_lead_activity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.crm_leads
  SET last_activity_at = COALESCE(GREATEST(COALESCE(last_activity_at, 'epoch'), NEW.created_at), NEW.created_at)
  WHERE id = NEW.lead_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path='';

DROP TRIGGER IF EXISTS trg_crm_touch_lead_activity ON public.crm_activities;
CREATE TRIGGER trg_crm_touch_lead_activity
  AFTER INSERT ON public.crm_activities
  FOR EACH ROW EXECUTE FUNCTION public.crm_touch_lead_activity();

-- Log stage changes and compute duration in previous stage
CREATE OR REPLACE FUNCTION public.crm_log_stage_change()
RETURNS TRIGGER AS $$
DECLARE
  prev_stage TIMESTAMPTZ;
  duration_sec INTEGER;
  new_status TEXT := NEW.status;
  target_is_won BOOLEAN := false;
  target_is_lost BOOLEAN := false;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.current_stage_id IS DISTINCT FROM OLD.current_stage_id THEN
    prev_stage := OLD.stage_entered_at;
    IF prev_stage IS NOT NULL THEN
      duration_sec := EXTRACT(EPOCH FROM (now() - prev_stage));
    ELSE
      duration_sec := NULL;
    END IF;

    -- Check target stage flags
    SELECT cs.is_won, cs.is_lost INTO target_is_won, target_is_lost
    FROM public.crm_stages cs WHERE cs.id = NEW.current_stage_id;

    IF target_is_won THEN new_status := 'won'; END IF;
    IF target_is_lost THEN new_status := 'lost'; END IF;

    INSERT INTO public.crm_lead_stage_history (
      law_firm_id, lead_id, from_stage_id, to_stage_id, changed_at, changed_by, duration_seconds
    ) VALUES (
      NEW.law_firm_id, NEW.id, OLD.current_stage_id, NEW.current_stage_id, now(), auth.uid(), duration_sec
    );

    NEW.stage_entered_at := now();
    NEW.status := COALESCE(new_status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path='';

DROP TRIGGER IF EXISTS trg_crm_log_stage_change ON public.crm_leads;
CREATE TRIGGER trg_crm_log_stage_change
  BEFORE UPDATE ON public.crm_leads
  FOR EACH ROW EXECUTE FUNCTION public.crm_log_stage_change();

COMMIT;