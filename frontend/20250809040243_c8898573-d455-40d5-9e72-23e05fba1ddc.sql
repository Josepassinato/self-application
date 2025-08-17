-- CRM Pipeline/Funnel core schema with RLS and triggers
BEGIN;

-- Pipelines
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

-- Stages
CREATE TABLE IF NOT EXISTS public.crm_stages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  pipeline_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  is_won BOOLEAN NOT NULL DEFAULT false,
  is_lost BOOLEAN NOT NULL DEFAULT false,
  probability INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Leads
CREATE TABLE IF NOT EXISTS public.crm_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  pipeline_id UUID NOT NULL,
  current_stage_id UUID,
  title TEXT NOT NULL,
  description TEXT,
  source TEXT,
  tags TEXT[] NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'open',
  contact_name TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  company TEXT,
  value NUMERIC NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'BRL',
  stage_entered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_activity_at TIMESTAMPTZ,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Automations
CREATE TABLE IF NOT EXISTS public.crm_automations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  trigger_type TEXT NOT NULL,
  trigger_config JSONB NOT NULL DEFAULT '{}'::jsonb,
  actions JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- FKs
ALTER TABLE public.crm_stages
  ADD CONSTRAINT IF NOT EXISTS crm_stages_pipeline_fk
  FOREIGN KEY (pipeline_id) REFERENCES public.crm_pipelines(id) ON DELETE CASCADE;

ALTER TABLE public.crm_stages
  ADD CONSTRAINT IF NOT EXISTS crm_stages_firm_fk
  FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id) ON DELETE CASCADE;

ALTER TABLE public.crm_leads
  ADD CONSTRAINT IF NOT EXISTS crm_leads_pipeline_fk
  FOREIGN KEY (pipeline_id) REFERENCES public.crm_pipelines(id) ON DELETE CASCADE;

ALTER TABLE public.crm_leads
  ADD CONSTRAINT IF NOT EXISTS crm_leads_stage_fk
  FOREIGN KEY (current_stage_id) REFERENCES public.crm_stages(id) ON DELETE SET NULL;

ALTER TABLE public.crm_leads
  ADD CONSTRAINT IF NOT EXISTS crm_leads_firm_fk
  FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id) ON DELETE CASCADE;

ALTER TABLE public.crm_pipelines
  ADD CONSTRAINT IF NOT EXISTS crm_pipelines_firm_fk
  FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id) ON DELETE CASCADE;

ALTER TABLE public.crm_automations
  ADD CONSTRAINT IF NOT EXISTS crm_automations_firm_fk
  FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id) ON DELETE CASCADE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_crm_pipelines_firm ON public.crm_pipelines(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_crm_stages_firm ON public.crm_stages(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_crm_stages_pipeline ON public.crm_stages(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_firm ON public.crm_leads(law_firm_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_pipeline ON public.crm_leads(pipeline_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_stage ON public.crm_leads(current_stage_id);
CREATE INDEX IF NOT EXISTS idx_crm_leads_status ON public.crm_leads(status);
CREATE INDEX IF NOT EXISTS idx_crm_leads_tags ON public.crm_leads USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_crm_automations_firm ON public.crm_automations(law_firm_id);

-- RLS
ALTER TABLE public.crm_pipelines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.crm_automations ENABLE ROW LEVEL SECURITY;

-- Policies: Pipelines
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_pipelines' AND policyname = 'Firm users can view pipelines'
  ) THEN
    CREATE POLICY "Firm users can view pipelines" ON public.crm_pipelines
      FOR SELECT USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_pipelines' AND policyname = 'Firm users can manage pipelines'
  ) THEN
    CREATE POLICY "Firm users can manage pipelines" ON public.crm_pipelines
      FOR ALL USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      ) WITH CHECK (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Policies: Stages
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_stages' AND policyname = 'Firm users can view stages'
  ) THEN
    CREATE POLICY "Firm users can view stages" ON public.crm_stages
      FOR SELECT USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_stages' AND policyname = 'Firm users can manage stages'
  ) THEN
    CREATE POLICY "Firm users can manage stages" ON public.crm_stages
      FOR ALL USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      ) WITH CHECK (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Policies: Leads
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_leads' AND policyname = 'Firm users can view leads'
  ) THEN
    CREATE POLICY "Firm users can view leads" ON public.crm_leads
      FOR SELECT USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_leads' AND policyname = 'Firm users can manage leads'
  ) THEN
    CREATE POLICY "Firm users can manage leads" ON public.crm_leads
      FOR ALL USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      ) WITH CHECK (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Policies: Automations
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_automations' AND policyname = 'Firm users can view automations'
  ) THEN
    CREATE POLICY "Firm users can view automations" ON public.crm_automations
      FOR SELECT USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'crm_automations' AND policyname = 'Firm users can manage automations'
  ) THEN
    CREATE POLICY "Firm users can manage automations" ON public.crm_automations
      FOR ALL USING (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      ) WITH CHECK (
        law_firm_id IN (
          SELECT pu.law_firm_id FROM public.platform_users pu WHERE pu.auth_user_id = auth.uid()
        )
      );
  END IF;
END $$;

-- Triggers for updated_at
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_set_updated_at_crm_pipelines'
  ) THEN
    CREATE TRIGGER tr_set_updated_at_crm_pipelines
      BEFORE UPDATE ON public.crm_pipelines
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_set_updated_at_crm_stages'
  ) THEN
    CREATE TRIGGER tr_set_updated_at_crm_stages
      BEFORE UPDATE ON public.crm_stages
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_set_updated_at_crm_leads'
  ) THEN
    CREATE TRIGGER tr_set_updated_at_crm_leads
      BEFORE UPDATE ON public.crm_leads
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_set_updated_at_crm_automations'
  ) THEN
    CREATE TRIGGER tr_set_updated_at_crm_automations
      BEFORE UPDATE ON public.crm_automations
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

-- Trigger to log stage changes (uses existing function public.crm_log_stage_change)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_log_stage_change'
  ) THEN
    CREATE TRIGGER tr_log_stage_change
      BEFORE UPDATE ON public.crm_leads
      FOR EACH ROW EXECUTE FUNCTION public.crm_log_stage_change();
  END IF;
END $$;

-- Touch lead last_activity when new activity is created (uses existing function public.crm_touch_lead_activity)
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'crm_activities'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM pg_proc WHERE proname = 'crm_touch_lead_activity'
    ) THEN
      -- drop if exists to ensure correct definition
      IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'tr_crm_touch_lead_activity') THEN
        DROP TRIGGER tr_crm_touch_lead_activity ON public.crm_activities;
      END IF;
      CREATE TRIGGER tr_crm_touch_lead_activity
        AFTER INSERT ON public.crm_activities
        FOR EACH ROW EXECUTE FUNCTION public.crm_touch_lead_activity();
    END IF;
  END IF;
END $$;

COMMIT;