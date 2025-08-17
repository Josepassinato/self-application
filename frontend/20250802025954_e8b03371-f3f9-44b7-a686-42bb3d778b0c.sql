-- Criar tabela para armazenar formulários de imigração
CREATE TABLE public.immigration_forms (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  form_code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  description TEXT,
  country TEXT NOT NULL,
  visa_type TEXT NOT NULL,
  form_structure JSONB NOT NULL DEFAULT '{}',
  prompt_template_id UUID,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id)
);

-- Criar tabela para templates de prompts
CREATE TABLE public.prompt_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  prompt_text TEXT NOT NULL,
  variables JSONB NOT NULL DEFAULT '[]',
  version INTEGER NOT NULL DEFAULT 1,
  is_active BOOLEAN NOT NULL DEFAULT true,
  category TEXT NOT NULL DEFAULT 'general',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id)
);

-- Criar tabela para auditoria de templates
CREATE TABLE public.template_audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  template_id UUID NOT NULL REFERENCES prompt_templates(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  changes JSONB,
  performed_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.immigration_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_audit_logs ENABLE ROW LEVEL SECURITY;

-- Políticas para immigration_forms
CREATE POLICY "Users can view immigration forms" 
ON public.immigration_forms 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can manage immigration forms" 
ON public.immigration_forms 
FOR ALL 
USING (is_user_admin(auth.uid()) = true);

-- Políticas para prompt_templates
CREATE POLICY "Users can view prompt templates" 
ON public.prompt_templates 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can manage prompt templates" 
ON public.prompt_templates 
FOR ALL 
USING (is_user_admin(auth.uid()) = true);

-- Políticas para template_audit_logs
CREATE POLICY "Admins can view audit logs" 
ON public.template_audit_logs 
FOR SELECT 
USING (is_user_admin(auth.uid()) = true);

CREATE POLICY "System can create audit logs" 
ON public.template_audit_logs 
FOR INSERT 
WITH CHECK (true);

-- Trigger para atualizar updated_at
CREATE TRIGGER update_immigration_forms_updated_at
BEFORE UPDATE ON public.immigration_forms
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_prompt_templates_updated_at
BEFORE UPDATE ON public.prompt_templates
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger para auditoria de prompt templates
CREATE OR REPLACE FUNCTION public.audit_prompt_template_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    INSERT INTO public.template_audit_logs (template_id, action, changes, performed_by)
    VALUES (NEW.id, 'updated', to_jsonb(NEW) - to_jsonb(OLD), auth.uid());
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.template_audit_logs (template_id, action, changes, performed_by)
    VALUES (OLD.id, 'deleted', to_jsonb(OLD), auth.uid());
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_prompt_template_changes
AFTER UPDATE OR DELETE ON public.prompt_templates
FOR EACH ROW
EXECUTE FUNCTION public.audit_prompt_template_changes();

-- Inserir formulários de imigração padrão
INSERT INTO public.immigration_forms (form_code, title, description, country, visa_type, form_structure) VALUES
('I-130', 'Petition for Alien Relative', 'Petition for family-based immigration', 'USA', 'Family', '{
  "sections": [
    {
      "title": "Information About You (Petitioner)",
      "fields": [
        {"name": "full_name", "type": "text", "required": true, "label": "Full Legal Name"},
        {"name": "address", "type": "address", "required": true, "label": "Current Address"},
        {"name": "birth_date", "type": "date", "required": true, "label": "Date of Birth"},
        {"name": "birth_place", "type": "text", "required": true, "label": "Place of Birth"}
      ]
    },
    {
      "title": "Information About Beneficiary",
      "fields": [
        {"name": "beneficiary_name", "type": "text", "required": true, "label": "Full Legal Name"},
        {"name": "relationship", "type": "select", "required": true, "label": "Relationship to Petitioner", "options": ["Spouse", "Child", "Parent", "Sibling"]},
        {"name": "beneficiary_birth_date", "type": "date", "required": true, "label": "Date of Birth"},
        {"name": "beneficiary_birth_place", "type": "text", "required": true, "label": "Place of Birth"}
      ]
    }
  ]
}'),
('I-485', 'Application to Adjust Status', 'Application for adjustment of status to permanent resident', 'USA', 'Adjustment', '{
  "sections": [
    {
      "title": "Applicant Information",
      "fields": [
        {"name": "full_name", "type": "text", "required": true, "label": "Full Legal Name"},
        {"name": "other_names", "type": "text", "required": false, "label": "Other Names Used"},
        {"name": "address", "type": "address", "required": true, "label": "Current Address"},
        {"name": "birth_date", "type": "date", "required": true, "label": "Date of Birth"}
      ]
    },
    {
      "title": "Immigration History",
      "fields": [
        {"name": "entry_date", "type": "date", "required": true, "label": "Date of Last Entry to US"},
        {"name": "entry_status", "type": "text", "required": true, "label": "Immigration Status at Entry"},
        {"name": "current_status", "type": "text", "required": true, "label": "Current Immigration Status"}
      ]
    }
  ]
}');

-- Inserir templates de prompts padrão
INSERT INTO public.prompt_templates (name, description, prompt_text, variables, category) VALUES
('Form Validation Prompt', 'Template para validação de formulários de imigração', 'Analise o seguinte formulário de imigração e identifique possíveis erros ou informações em falta:

Formulário: {{form_type}}
Dados preenchidos: {{form_data}}

Verifique:
1. Campos obrigatórios preenchidos
2. Formatos de data corretos
3. Consistência das informações
4. Documentos necessários

Forneça uma lista de problemas encontrados e sugestões de correção.', '["form_type", "form_data"]', 'validation'),

('Document Requirements Prompt', 'Template para listar documentos necessários', 'Com base no tipo de visto {{visa_type}} e país {{country}}, liste todos os documentos necessários para a aplicação.

Informações do candidato:
{{applicant_info}}

Forneça uma lista detalhada dos documentos necessários, incluindo:
1. Documentos obrigatórios
2. Documentos opcionais mas recomendados
3. Requisitos específicos para cada documento
4. Prazo de validade dos documentos', '["visa_type", "country", "applicant_info"]', 'documentation'),

('Timeline Estimation Prompt', 'Template para estimativa de prazo', 'Estime o tempo de processamento para o seguinte caso de imigração:

Tipo de visto: {{visa_type}}
País: {{country}}
Situação do candidato: {{applicant_status}}
Complexidade do caso: {{case_complexity}}

Forneça uma estimativa realista considerando:
1. Tempo médio de processamento atual
2. Fatores que podem acelerar o processo
3. Fatores que podem atrasar o processo
4. Etapas do processo e duração estimada de cada uma', '["visa_type", "country", "applicant_status", "case_complexity"]', 'timeline');