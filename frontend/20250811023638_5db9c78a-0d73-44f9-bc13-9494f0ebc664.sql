-- Form Engine base tables
-- 1) forms_registry: stores schema and PDF field mapping per form/version
CREATE TABLE IF NOT EXISTS public.forms_registry (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_code TEXT NOT NULL,
  version TEXT NOT NULL,
  pdf_hash TEXT,
  schema_json JSONB NOT NULL,
  field_map JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Helpful index to quickly find by code+version
CREATE INDEX IF NOT EXISTS idx_forms_registry_code_version ON public.forms_registry (form_code, version);

-- 2) case_forms: user-filled data per case and form version
CREATE TABLE IF NOT EXISTS public.case_forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID REFERENCES public.cases (id) ON DELETE SET NULL,
  form_code TEXT NOT NULL,
  version TEXT NOT NULL,
  data_json JSONB NOT NULL,
  validation_errors JSONB,
  output_uri TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_case_forms_case_id ON public.case_forms (case_id);
CREATE INDEX IF NOT EXISTS idx_case_forms_code_version ON public.case_forms (form_code, version);

-- Row Level Security
ALTER TABLE public.forms_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_forms ENABLE ROW LEVEL SECURITY;

-- Update timestamp trigger using existing utility function
DROP TRIGGER IF EXISTS update_case_forms_updated_at ON public.case_forms;
CREATE TRIGGER update_case_forms_updated_at
BEFORE UPDATE ON public.case_forms
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_forms_registry_updated_at ON public.forms_registry;
CREATE TRIGGER update_forms_registry_updated_at
BEFORE UPDATE ON public.forms_registry
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Policies for forms_registry
DROP POLICY IF EXISTS "Anyone can view form schemas" ON public.forms_registry;
CREATE POLICY "Anyone can view form schemas"
ON public.forms_registry
FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Admins can insert form schemas" ON public.forms_registry;
CREATE POLICY "Admins can insert form schemas"
ON public.forms_registry
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid() AND pu.role IN ('admin','saas_admin')
  )
);

DROP POLICY IF EXISTS "Admins can update form schemas" ON public.forms_registry;
CREATE POLICY "Admins can update form schemas"
ON public.forms_registry
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid() AND pu.role IN ('admin','saas_admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid() AND pu.role IN ('admin','saas_admin')
  )
);

-- Policies for case_forms (mirror case_activities logic: firm-bound based on case -> client.responsavel)
DROP POLICY IF EXISTS "Lawyers can view case forms in firm" ON public.case_forms;
CREATE POLICY "Lawyers can view case forms in firm"
ON public.case_forms
FOR SELECT
USING (
  EXISTS (
    SELECT 1
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = public.case_forms.case_id
      AND pu.law_firm_id IN (
        SELECT responsavel.law_firm_id
        FROM public.platform_users responsavel
        WHERE responsavel.auth_user_id = cl.responsavel_id
      )
  )
);

DROP POLICY IF EXISTS "Lawyers can manage case forms in firm" ON public.case_forms;
CREATE POLICY "Lawyers can manage case forms in firm"
ON public.case_forms
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = public.case_forms.case_id
      AND pu.law_firm_id IN (
        SELECT responsavel.law_firm_id
        FROM public.platform_users responsavel
        WHERE responsavel.auth_user_id = cl.responsavel_id
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = public.case_forms.case_id
      AND pu.law_firm_id IN (
        SELECT responsavel.law_firm_id
        FROM public.platform_users responsavel
        WHERE responsavel.auth_user_id = cl.responsavel_id
      )
  )
);
