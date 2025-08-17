-- Criar tabela para formulários de imigração mapeados
CREATE TABLE public.immigration_forms (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  form_code TEXT NOT NULL UNIQUE, -- I-129, DS-160, etc.
  form_name TEXT NOT NULL,
  form_category TEXT NOT NULL, -- 'USCIS', 'DOS', etc.
  form_description TEXT,
  fields_schema JSONB NOT NULL DEFAULT '{}', -- Schema dos campos do formulário
  validation_rules JSONB DEFAULT '{}', -- Regras de validação
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Criar tabela para templates de prompts versionados
CREATE TABLE public.prompt_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  form_id UUID REFERENCES public.immigration_forms(id),
  template_name TEXT NOT NULL,
  template_type TEXT NOT NULL, -- 'generation', 'validation', 'analysis'
  version INTEGER NOT NULL DEFAULT 1,
  prompt_content TEXT NOT NULL,
  variables JSONB DEFAULT '[]', -- Variáveis do template
  metadata JSONB DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  parent_version_id UUID REFERENCES public.prompt_templates(id), -- Para tracking de versões
  created_by UUID,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(law_firm_id, form_id, template_type, version)
);

-- Criar tabela para auditoria de templates
CREATE TABLE public.template_audit_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  template_id UUID NOT NULL REFERENCES public.prompt_templates(id),
  law_firm_id UUID NOT NULL,
  action TEXT NOT NULL, -- 'created', 'updated', 'activated', 'deactivated'
  changes JSONB DEFAULT '{}', -- Detalhes das mudanças
  changed_by UUID,
  reason TEXT, -- Motivo da mudança
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.immigration_forms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prompt_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.template_audit_logs ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para immigration_forms (público para leitura)
CREATE POLICY "Anyone can view immigration forms"
ON public.immigration_forms
FOR SELECT
USING (true);

-- Políticas RLS para prompt_templates
CREATE POLICY "Users can view templates from their firm"
ON public.prompt_templates
FOR SELECT
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id
  FROM platform_users
  WHERE platform_users.auth_user_id = auth.uid()
));

CREATE POLICY "Users can manage templates in their firm"
ON public.prompt_templates
FOR ALL
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id
  FROM platform_users
  WHERE platform_users.auth_user_id = auth.uid()
));

-- Políticas RLS para template_audit_logs
CREATE POLICY "Users can view audit logs from their firm"
ON public.template_audit_logs
FOR SELECT
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id
  FROM platform_users
  WHERE platform_users.auth_user_id = auth.uid()
));

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

-- Inserir formulários de imigração padrão
INSERT INTO public.immigration_forms (form_code, form_name, form_category, form_description, fields_schema) VALUES
('I-129', 'Petition for Nonimmigrant Worker', 'USCIS', 'Petição para trabalhador não-imigrante', '{
  "petitioner_info": {
    "company_name": "text",
    "address": "address",
    "tax_id": "text",
    "contact_person": "text"
  },
  "beneficiary_info": {
    "full_name": "text",
    "date_of_birth": "date",
    "country_of_birth": "text",
    "passport_number": "text"
  },
  "petition_type": {
    "classification": "select",
    "requested_action": "select",
    "start_date": "date",
    "end_date": "date"
  }
}'),
('DS-160', 'Online Nonimmigrant Visa Application', 'DOS', 'Formulário online para solicitação de visto não-imigrante', '{
  "personal_info": {
    "surname": "text",
    "given_names": "text",
    "date_of_birth": "date",
    "place_of_birth": "text"
  },
  "passport_info": {
    "passport_number": "text",
    "country_of_issuance": "text",
    "issuance_date": "date",
    "expiration_date": "date"
  },
  "travel_info": {
    "purpose_of_trip": "select",
    "intended_date_of_arrival": "date",
    "intended_length_of_stay": "text"
  }
}'),
('I-140', 'Petition for Alien Worker', 'USCIS', 'Petição para trabalhador estrangeiro (Green Card)', '{
  "petitioner_info": {
    "company_name": "text",
    "address": "address",
    "business_type": "text"
  },
  "beneficiary_info": {
    "full_name": "text",
    "country_of_birth": "text",
    "priority_date": "date"
  },
  "classification": {
    "category": "select",
    "job_title": "text",
    "job_description": "textarea"
  }
}'),
('I-485', 'Application to Register Permanent Residence', 'USCIS', 'Aplicação para ajuste de status para residente permanente', '{
  "applicant_info": {
    "full_name": "text",
    "date_of_birth": "date",
    "country_of_birth": "text"
  },
  "current_status": {
    "current_immigration_status": "text",
    "date_of_last_arrival": "date",
    "i94_number": "text"
  },
  "basis_for_application": {
    "category": "select",
    "priority_date": "date"
  }
}'),
('I-130', 'Petition for Alien Relative', 'USCIS', 'Petição para parente estrangeiro', '{
  "petitioner_info": {
    "full_name": "text",
    "relationship_to_beneficiary": "select",
    "us_citizen": "boolean"
  },
  "beneficiary_info": {
    "full_name": "text",
    "date_of_birth": "date",
    "country_of_birth": "text"
  }
}'),
('I-751', 'Petition to Remove Conditions on Residence', 'USCIS', 'Petição para remover condições da residência', '{
  "petitioner_info": {
    "full_name": "text",
    "date_conditional_residence_obtained": "date",
    "card_number": "text"
  },
  "basis_for_petition": {
    "reason": "select",
    "joint_filing": "boolean"
  }
}');