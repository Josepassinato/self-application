-- Tabela para templates de documentos
CREATE TABLE public.document_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL, -- 'petition', 'form', 'letter', 'contract'
  file_content TEXT NOT NULL, -- Template content with placeholders
  variables JSONB DEFAULT '[]'::jsonb, -- Array of variable names used in template
  visa_types TEXT[] DEFAULT '{}', -- Which visa types this template applies to
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID
);

-- Tabela para templates de email
CREATE TABLE public.email_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  category TEXT NOT NULL, -- 'welcome', 'status_update', 'reminder', 'follow_up'
  variables JSONB DEFAULT '[]'::jsonb,
  visa_types TEXT[] DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID
);

-- Tabela para workflows automatizados
CREATE TABLE public.workflow_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  visa_type TEXT NOT NULL,
  workflow_steps JSONB NOT NULL, -- Array of steps with conditions and actions
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID
);

-- Tabela para templates de checklist
CREATE TABLE public.checklist_templates (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  visa_types TEXT[] NOT NULL,
  checklist_items JSONB NOT NULL, -- Array of checklist items with conditions
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID
);

-- Tabela para checklists específicos de casos
CREATE TABLE public.case_checklists (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  case_id UUID NOT NULL,
  template_id UUID,
  checklist_data JSONB NOT NULL, -- Current state of checklist items
  completion_percentage INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Tabela para histórico de automação
CREATE TABLE public.automation_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  case_id UUID NOT NULL,
  automation_type TEXT NOT NULL, -- 'workflow', 'template', 'email', 'checklist'
  template_id UUID,
  action_performed TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'completed', -- 'pending', 'completed', 'failed'
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  performed_by UUID
);

-- Enable RLS
ALTER TABLE public.document_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflow_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checklist_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.automation_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies para document_templates
CREATE POLICY "Users can manage templates in their firm" ON public.document_templates
FOR ALL USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

-- RLS Policies para email_templates
CREATE POLICY "Users can manage email templates in their firm" ON public.email_templates
FOR ALL USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

-- RLS Policies para workflow_templates
CREATE POLICY "Users can manage workflows in their firm" ON public.workflow_templates
FOR ALL USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

-- RLS Policies para checklist_templates
CREATE POLICY "Users can manage checklist templates in their firm" ON public.checklist_templates
FOR ALL USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

-- RLS Policies para case_checklists
CREATE POLICY "Users can manage case checklists in their firm" ON public.case_checklists
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = case_checklists.case_id
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id
      FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = cl.responsavel_id
    )
  )
);

-- RLS Policies para automation_logs
CREATE POLICY "Users can view automation logs in their firm" ON public.automation_logs
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = automation_logs.case_id
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id
      FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "Users can create automation logs in their firm" ON public.automation_logs
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE c.id = automation_logs.case_id
    AND pu.law_firm_id IN (
      SELECT responsavel.law_firm_id
      FROM public.platform_users responsavel
      WHERE responsavel.auth_user_id = cl.responsavel_id
    )
  )
);

-- Foreign keys
ALTER TABLE public.document_templates 
ADD CONSTRAINT document_templates_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

ALTER TABLE public.email_templates 
ADD CONSTRAINT email_templates_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

ALTER TABLE public.workflow_templates 
ADD CONSTRAINT workflow_templates_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

ALTER TABLE public.checklist_templates 
ADD CONSTRAINT checklist_templates_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

ALTER TABLE public.case_checklists 
ADD CONSTRAINT case_checklists_case_id_fkey 
FOREIGN KEY (case_id) REFERENCES public.cases(id);

ALTER TABLE public.case_checklists 
ADD CONSTRAINT case_checklists_template_id_fkey 
FOREIGN KEY (template_id) REFERENCES public.checklist_templates(id);

ALTER TABLE public.automation_logs 
ADD CONSTRAINT automation_logs_case_id_fkey 
FOREIGN KEY (case_id) REFERENCES public.cases(id);

-- Triggers para updated_at
CREATE TRIGGER update_document_templates_updated_at
BEFORE UPDATE ON public.document_templates
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_email_templates_updated_at
BEFORE UPDATE ON public.email_templates
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_workflow_templates_updated_at
BEFORE UPDATE ON public.workflow_templates
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_checklist_templates_updated_at
BEFORE UPDATE ON public.checklist_templates
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_case_checklists_updated_at
BEFORE UPDATE ON public.case_checklists
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Função para aplicar checklist automaticamente quando caso é criado
CREATE OR REPLACE FUNCTION public.apply_checklist_template()
RETURNS TRIGGER AS $$
BEGIN
  -- Aplicar template de checklist baseado no tipo de visto
  INSERT INTO public.case_checklists (case_id, template_id, checklist_data)
  SELECT 
    NEW.id,
    ct.id,
    ct.checklist_items
  FROM public.checklist_templates ct
  WHERE ct.is_active = true
    AND NEW.tipo_visto = ANY(ct.visa_types)
    AND ct.law_firm_id IN (
      SELECT pu.law_firm_id 
      FROM public.platform_users pu 
      JOIN public.clients c ON c.responsavel_id = pu.auth_user_id
      WHERE c.id = NEW.client_id
    )
  LIMIT 1;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para aplicar checklist automaticamente
CREATE TRIGGER apply_checklist_on_case_creation
AFTER INSERT ON public.cases
FOR EACH ROW
EXECUTE FUNCTION public.apply_checklist_template();

-- Inserir alguns templates de exemplo
INSERT INTO public.document_templates (law_firm_id, name, description, category, file_content, variables, visa_types) VALUES
('00000000-0000-0000-0000-000000000000', 'Petition Letter Template', 'Standard petition letter for work visas', 'petition', 
'Dear Immigration Officer,

I am writing to petition for {{client_name}} ({{client_nationality}} national) for a {{visa_type}} visa.

{{client_name}} has been offered employment with {{company_name}} as a {{job_title}}. The position requires {{job_requirements}}.

Educational Background:
{{education_details}}

Work Experience:
{{work_experience}}

We respectfully request that you approve this petition.

Sincerely,
{{attorney_name}}
{{attorney_title}}', 
'["client_name", "client_nationality", "visa_type", "company_name", "job_title", "job_requirements", "education_details", "work_experience", "attorney_name", "attorney_title"]',
'{"H1B", "L1", "O1"}'),

('00000000-0000-0000-0000-000000000000', 'Welcome Email', 'Welcome email for new clients', 'welcome',
'Welcome to our immigration services!

Dear {{client_name}},

Thank you for choosing our firm to assist with your {{visa_type}} application. We are committed to providing you with excellent service throughout this process.

Next Steps:
1. Review and complete the attached forms
2. Gather required documents
3. Schedule your consultation

Your case has been assigned reference number: {{case_id}}

Best regards,
{{attorney_name}}',
'["client_name", "visa_type", "case_id", "attorney_name"]',
'{}');

INSERT INTO public.email_templates (law_firm_id, name, subject, body, category, variables, visa_types) VALUES
('00000000-0000-0000-0000-000000000000', 'Status Update', 'Case Update - {{case_title}}', 
'Dear {{client_name}},

We wanted to update you on the progress of your {{visa_type}} application.

Current Status: {{current_status}}
Next Steps: {{next_steps}}

{{additional_notes}}

If you have any questions, please don''t hesitate to contact us.

Best regards,
{{attorney_name}}', 
'status_update',
'["client_name", "visa_type", "case_title", "current_status", "next_steps", "additional_notes", "attorney_name"]',
'{}'),

('00000000-0000-0000-0000-000000000000', 'Document Reminder', 'Missing Documents - {{case_title}}',
'Dear {{client_name}},

We are still missing the following documents for your {{visa_type}} application:

{{missing_documents}}

Please submit these as soon as possible to avoid delays in processing.

Best regards,
{{attorney_name}}',
'reminder',
'["client_name", "visa_type", "case_title", "missing_documents", "attorney_name"]',
'{}');

INSERT INTO public.checklist_templates (law_firm_id, name, description, visa_types, checklist_items) VALUES
('00000000-0000-0000-0000-000000000000', 'H1B Checklist', 'Standard checklist for H1B applications', '{"H1B"}',
'[
  {
    "id": "passport",
    "title": "Valid Passport",
    "description": "Client passport with at least 6 months validity",
    "required": true,
    "category": "documents",
    "completed": false
  },
  {
    "id": "diploma",
    "title": "Educational Diploma",
    "description": "Degree certificate and transcripts",
    "required": true,
    "category": "documents",
    "completed": false
  },
  {
    "id": "offer_letter",
    "title": "Job Offer Letter",
    "description": "Signed offer letter from US employer",
    "required": true,
    "category": "documents",
    "completed": false
  },
  {
    "id": "lca",
    "title": "Labor Condition Application",
    "description": "Approved LCA from Department of Labor",
    "required": true,
    "category": "legal",
    "completed": false
  },
  {
    "id": "petition_filing",
    "title": "File I-129 Petition",
    "description": "Submit petition to USCIS",
    "required": true,
    "category": "filing",
    "completed": false
  }
]'),

('00000000-0000-0000-0000-000000000000', 'Tourist Visa Checklist', 'Standard checklist for B1/B2 applications', '{"B1", "B2"}',
'[
  {
    "id": "passport",
    "title": "Valid Passport",
    "description": "Client passport with at least 6 months validity",
    "required": true,
    "category": "documents",
    "completed": false
  },
  {
    "id": "ds160",
    "title": "DS-160 Form",
    "description": "Complete online DS-160 application",
    "required": true,
    "category": "forms",
    "completed": false
  },
  {
    "id": "photo",
    "title": "Passport Photo",
    "description": "Recent passport-style photograph",
    "required": true,
    "category": "documents",
    "completed": false
  },
  {
    "id": "financial_support",
    "title": "Financial Documents",
    "description": "Bank statements and proof of financial support",
    "required": true,
    "category": "documents",
    "completed": false
  },
  {
    "id": "interview",
    "title": "Embassy Interview",
    "description": "Schedule and attend visa interview",
    "required": true,
    "category": "appointments",
    "completed": false
  }
]');

INSERT INTO public.workflow_templates (law_firm_id, name, description, visa_type, workflow_steps) VALUES
('00000000-0000-0000-0000-000000000000', 'H1B Standard Workflow', 'Standard workflow for H1B applications', 'H1B',
'[
  {
    "step": 1,
    "name": "Initial Consultation",
    "description": "Meet with client to assess case",
    "estimated_days": 1,
    "dependencies": [],
    "actions": [
      {
        "type": "send_email",
        "template": "welcome_email",
        "trigger": "case_created"
      }
    ]
  },
  {
    "step": 2,
    "name": "Document Collection",
    "description": "Gather all required documents",
    "estimated_days": 14,
    "dependencies": [1],
    "actions": [
      {
        "type": "apply_checklist",
        "template": "h1b_checklist",
        "trigger": "step_started"
      },
      {
        "type": "send_reminder",
        "template": "document_reminder",
        "trigger": "7_days_after_start"
      }
    ]
  },
  {
    "step": 3,
    "name": "LCA Filing",
    "description": "File Labor Condition Application",
    "estimated_days": 7,
    "dependencies": [2],
    "actions": []
  },
  {
    "step": 4,
    "name": "I-129 Preparation",
    "description": "Prepare and review I-129 petition",
    "estimated_days": 5,
    "dependencies": [3],
    "actions": [
      {
        "type": "generate_document",
        "template": "i129_petition",
        "trigger": "step_started"
      }
    ]
  },
  {
    "step": 5,
    "name": "File Petition",
    "description": "Submit I-129 to USCIS",
    "estimated_days": 1,
    "dependencies": [4],
    "actions": [
      {
        "type": "update_status",
        "status": "petition_filed",
        "trigger": "step_completed"
      },
      {
        "type": "send_email",
        "template": "filing_confirmation",
        "trigger": "step_completed"
      }
    ]
  }
]');