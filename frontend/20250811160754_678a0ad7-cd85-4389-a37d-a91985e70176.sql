-- Criar tabela para armazenar resultados de validação de qualidade
CREATE TABLE public.case_quality_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  check_type TEXT NOT NULL, -- missing_field, inconsistent_data, invalid_format, duplicate_case, etc
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'error')),
  field_name TEXT, -- campo específico com problema
  message TEXT NOT NULL,
  ai_suggestion JSONB,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'resolved', 'ignored')),
  resolution_note TEXT, -- justificativa quando ignorado
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  resolved_at TIMESTAMP WITH TIME ZONE,
  resolved_by UUID REFERENCES auth.users(id)
);

-- Criar índices para performance
CREATE INDEX idx_case_quality_checks_case_id ON public.case_quality_checks(case_id);
CREATE INDEX idx_case_quality_checks_status ON public.case_quality_checks(status);
CREATE INDEX idx_case_quality_checks_severity ON public.case_quality_checks(severity);
CREATE INDEX idx_case_quality_checks_check_type ON public.case_quality_checks(check_type);

-- Criar tabela para configurações de validação por tipo de visto
CREATE TABLE public.validation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visa_type TEXT NOT NULL,
  rule_type TEXT NOT NULL, -- required_field, format_validation, business_rule
  rule_config JSONB NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'error')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inserir regras de validação padrão
INSERT INTO public.validation_rules (visa_type, rule_type, rule_config, severity) VALUES
-- Regras gerais para todos os tipos de visto
('*', 'required_field', '{"field": "nome", "message": "Nome completo é obrigatório"}', 'error'),
('*', 'required_field', '{"field": "email", "message": "E-mail é obrigatório"}', 'error'),
('*', 'required_field', '{"field": "nacionalidade", "message": "Nacionalidade é obrigatória"}', 'error'),
('*', 'format_validation', '{"field": "email", "pattern": "^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$", "message": "Formato de e-mail inválido"}', 'error'),

-- Regras específicas para vistos de trabalho
('H1B', 'required_field', '{"field": "employer_name", "message": "Nome do empregador é obrigatório para H1B"}', 'error'),
('H1B', 'required_field', '{"field": "job_title", "message": "Cargo é obrigatório para H1B"}', 'error'),
('L1', 'required_field', '{"field": "company_relationship", "message": "Relacionamento entre empresas é obrigatório para L1"}', 'error'),

-- Regras para vistos familiares
('I130', 'required_field', '{"field": "relationship_type", "message": "Tipo de relacionamento familiar é obrigatório"}', 'error'),
('I130', 'required_field', '{"field": "relationship_evidence", "message": "Evidência do relacionamento é obrigatória"}', 'error');

-- Criar tabela para telemetria de quality gates
CREATE TABLE public.quality_gate_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  law_firm_id UUID NOT NULL,
  total_checks INTEGER NOT NULL DEFAULT 0,
  errors_found INTEGER NOT NULL DEFAULT 0,
  warnings_found INTEGER NOT NULL DEFAULT 0,
  ai_suggestions_generated INTEGER NOT NULL DEFAULT 0,
  ai_suggestions_accepted INTEGER NOT NULL DEFAULT 0,
  resolution_time_minutes INTEGER, -- tempo para resolver todos os problemas
  blocked_submission BOOLEAN DEFAULT FALSE,
  final_status TEXT CHECK (final_status IN ('passed', 'failed', 'ignored')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  resolved_at TIMESTAMP WITH TIME ZONE
);

-- Habilitar RLS
ALTER TABLE public.case_quality_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.validation_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quality_gate_metrics ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_quality_checks
CREATE POLICY "Users can view quality checks for their accessible cases" 
ON public.case_quality_checks 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.platform_users pu 
      WHERE pu.auth_user_id = auth.uid() 
      AND pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM public.platform_users resp 
        WHERE resp.auth_user_id = cl.responsavel_id
      )
    )
  )
);

CREATE POLICY "Users can manage quality checks for their accessible cases" 
ON public.case_quality_checks 
FOR ALL
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.platform_users pu 
      WHERE pu.auth_user_id = auth.uid() 
      AND pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM public.platform_users resp 
        WHERE resp.auth_user_id = cl.responsavel_id
      )
    )
  )
)
WITH CHECK (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.platform_users pu 
      WHERE pu.auth_user_id = auth.uid() 
      AND pu.law_firm_id IN (
        SELECT resp.law_firm_id 
        FROM public.platform_users resp 
        WHERE resp.auth_user_id = cl.responsavel_id
      )
    )
  )
);

-- Políticas para validation_rules
CREATE POLICY "Users can view validation rules" 
ON public.validation_rules 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can manage validation rules" 
ON public.validation_rules 
FOR ALL
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() 
    AND role IN ('admin', 'saas_admin')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() 
    AND role IN ('admin', 'saas_admin')
  )
);

-- Políticas para quality_gate_metrics
CREATE POLICY "Users can view metrics for their firm" 
ON public.quality_gate_metrics 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage quality gate metrics" 
ON public.quality_gate_metrics 
FOR ALL
USING (true)
WITH CHECK (true);

-- Triggers para updated_at
CREATE OR REPLACE FUNCTION public.update_validation_rules_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_validation_rules_updated_at
  BEFORE UPDATE ON public.validation_rules
  FOR EACH ROW
  EXECUTE FUNCTION public.update_validation_rules_updated_at();

-- Habilitar Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_quality_checks;
ALTER PUBLICATION supabase_realtime ADD TABLE public.quality_gate_metrics;