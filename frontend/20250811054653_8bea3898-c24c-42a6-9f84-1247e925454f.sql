-- Criar tabelas para Quality Gates e auditoria
CREATE TABLE IF NOT EXISTS public.package_quality_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  run_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  checks JSONB NOT NULL,
  score NUMERIC CHECK (score >= 0 AND score <= 100),
  status TEXT NOT NULL CHECK (status IN ('pass', 'fail', 'warning')),
  approved_by UUID,
  approved_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS public.template_releases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_code TEXT NOT NULL,
  version TEXT NOT NULL,
  schema_hash TEXT NOT NULL,
  checklist_hash TEXT NOT NULL,
  cover_letter_hash TEXT NOT NULL,
  toc_hash TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  changelog TEXT,
  UNIQUE(template_code, version)
);

CREATE TABLE IF NOT EXISTS public.package_exports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  exported_by UUID NOT NULL,
  exported_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  export_hash TEXT NOT NULL,
  previous_hash TEXT,
  audit_uri TEXT NOT NULL,
  signature TEXT,
  status TEXT DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed'))
);

-- Habilitar RLS
ALTER TABLE public.package_quality_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_releases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_exports ENABLE ROW LEVEL SECURITY;

-- Políticas RLS
CREATE POLICY "Users can view quality reports for their firm packages" ON public.package_quality_reports
FOR SELECT USING (
  package_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage quality reports" ON public.package_quality_reports
FOR ALL USING (true);

CREATE POLICY "Anyone can view template releases" ON public.template_releases
FOR SELECT USING (true);

CREATE POLICY "Admins can manage template releases" ON public.template_releases
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

CREATE POLICY "Users can view exports for their firm packages" ON public.package_exports
FOR SELECT USING (
  package_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage exports" ON public.package_exports
FOR ALL USING (true);

-- Índices
CREATE INDEX IF NOT EXISTS idx_package_quality_reports_package_id ON public.package_quality_reports(package_id);
CREATE INDEX IF NOT EXISTS idx_package_quality_reports_status ON public.package_quality_reports(status);
CREATE INDEX IF NOT EXISTS idx_template_releases_code_version ON public.template_releases(template_code, version);
CREATE INDEX IF NOT EXISTS idx_package_exports_package_id ON public.package_exports(package_id);
CREATE INDEX IF NOT EXISTS idx_package_exports_exported_at ON public.package_exports(exported_at);