-- Criar tabela de quality reports para packages
CREATE TABLE IF NOT EXISTS public.package_quality_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  package_id UUID NOT NULL,
  checks JSONB NOT NULL DEFAULT '[]'::jsonb,
  overall_score INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL CHECK (status IN ('pass', 'warn', 'fail')),
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
USING (
  package_id IN (
    SELECT c.id
    FROM cases c
    JOIN clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
       OR EXISTS (
         SELECT 1 FROM platform_users pu
         WHERE pu.auth_user_id = auth.uid()
           AND pu.law_firm_id IN (
             SELECT resp.law_firm_id
             FROM platform_users resp
             WHERE resp.auth_user_id = cl.responsavel_id
           )
       )
  )
);

CREATE POLICY "System can create quality reports"
ON public.package_quality_reports
FOR INSERT
WITH CHECK (true);

-- Políticas RLS para package_quality_overrides
CREATE POLICY "Admins can create overrides for their firm packages"
ON public.package_quality_overrides
FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM platform_users pu
    WHERE pu.auth_user_id = auth.uid()
      AND pu.role IN ('admin', 'saas_admin')
  )
  AND package_id IN (
    SELECT c.id
    FROM cases c
    JOIN clients cl ON cl.id = c.client_id
    WHERE EXISTS (
      SELECT 1 FROM platform_users pu
      WHERE pu.auth_user_id = auth.uid()
        AND pu.law_firm_id IN (
          SELECT resp.law_firm_id
          FROM platform_users resp
          WHERE resp.auth_user_id = cl.responsavel_id
        )
    )
  )
);

CREATE POLICY "Users can view overrides for their accessible packages"
ON public.package_quality_overrides
FOR SELECT
USING (
  package_id IN (
    SELECT c.id
    FROM cases c
    JOIN clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
       OR EXISTS (
         SELECT 1 FROM platform_users pu
         WHERE pu.auth_user_id = auth.uid()
           AND pu.law_firm_id IN (
             SELECT resp.law_firm_id
             FROM platform_users resp
             WHERE resp.auth_user_id = cl.responsavel_id
           )
       )
  )
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_package_quality_reports_package_id ON public.package_quality_reports(package_id);
CREATE INDEX IF NOT EXISTS idx_package_quality_reports_created_at ON public.package_quality_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_package_quality_overrides_package_id ON public.package_quality_overrides(package_id);