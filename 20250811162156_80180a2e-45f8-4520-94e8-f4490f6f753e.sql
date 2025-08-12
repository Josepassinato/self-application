-- Criar tabela de templates de casos
CREATE TABLE public.case_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  visa_type TEXT NOT NULL,
  description TEXT,
  default_forms JSONB DEFAULT '[]'::jsonb,
  default_checklist JSONB DEFAULT '[]'::jsonb,
  default_ai_prompts JSONB DEFAULT '{}'::jsonb,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID REFERENCES auth.users(id)
);

-- Criar índices para performance
CREATE INDEX idx_case_templates_law_firm_id ON public.case_templates(law_firm_id);
CREATE INDEX idx_case_templates_visa_type ON public.case_templates(visa_type);
CREATE INDEX idx_case_templates_active ON public.case_templates(is_active);

-- Habilitar RLS
ALTER TABLE public.case_templates ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_templates
CREATE POLICY "Users can view templates from their firm" 
ON public.case_templates 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage templates in their firm" 
ON public.case_templates 
FOR ALL
USING (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
    AND pu.role IN ('admin', 'saas_admin')
  )
)
WITH CHECK (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
    AND pu.role IN ('admin', 'saas_admin')
  )
);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION public.update_case_templates_updated_at()
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

CREATE TRIGGER update_case_templates_updated_at
  BEFORE UPDATE ON public.case_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.update_case_templates_updated_at();

-- Habilitar Realtime para updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_templates;