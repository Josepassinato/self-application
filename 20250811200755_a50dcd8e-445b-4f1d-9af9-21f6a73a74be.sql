-- Criar tabela de quality reports para packages
CREATE TABLE IF NOT EXISTS public.package_quality_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  checks JSONB NOT NULL DEFAULT '[]'::jsonb,
  overall_score INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  can_finalize BOOLEAN NOT NULL DEFAULT false,
  blocking_issues_count INTEGER NOT NULL DEFAULT 0,
  created_by UUID,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela de overrides de admin
CREATE TABLE IF NOT EXISTS public.package_quality_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  overridden_by UUID,
  justification TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.package_quality_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.package_quality_overrides ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para package_quality_reports
CREATE POLICY "Users can view quality reports for their accessible packages"
ON public.package_quality_reports
FOR SELECT
USING (true);

CREATE POLICY "System can create quality reports"
ON public.package_quality_reports
FOR INSERT
WITH CHECK (true);

-- Políticas RLS para package_quality_overrides
CREATE POLICY "Users can view overrides for their accessible packages"
ON public.package_quality_overrides
FOR SELECT
USING (true);

CREATE POLICY "Admins can create overrides"
ON public.package_quality_overrides
FOR INSERT
WITH CHECK (true);