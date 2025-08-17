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

-- Função para calcular porcentagem de completude do checklist
CREATE OR REPLACE FUNCTION public.update_checklist_completion()
RETURNS TRIGGER AS $$
DECLARE
  total_items INTEGER;
  completed_items INTEGER;
  completion_pct INTEGER;
BEGIN
  -- Contar total de itens no checklist
  SELECT jsonb_array_length(NEW.checklist_data) INTO total_items;
  
  -- Contar itens completados
  SELECT COUNT(*)::INTEGER INTO completed_items
  FROM jsonb_array_elements(NEW.checklist_data) AS item
  WHERE (item->>'completed')::boolean = true;
  
  -- Calcular porcentagem
  IF total_items > 0 THEN
    completion_pct := ROUND((completed_items::DECIMAL / total_items::DECIMAL) * 100);
  ELSE
    completion_pct := 0;
  END IF;
  
  NEW.completion_percentage := completion_pct;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar automaticamente a porcentagem de completude
CREATE TRIGGER update_checklist_completion_trigger
BEFORE UPDATE ON public.case_checklists
FOR EACH ROW
WHEN (OLD.checklist_data IS DISTINCT FROM NEW.checklist_data)
EXECUTE FUNCTION public.update_checklist_completion();