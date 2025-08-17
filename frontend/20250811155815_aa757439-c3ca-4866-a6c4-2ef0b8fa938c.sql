-- Adicionar campo preferred_language às tabelas clients e platform_users
ALTER TABLE public.clients 
ADD COLUMN preferred_language TEXT DEFAULT 'en' CHECK (preferred_language IN ('en', 'es', 'pt', 'zh', 'fr', 'de', 'it', 'ja', 'ko'));

ALTER TABLE public.platform_users 
ADD COLUMN preferred_language TEXT DEFAULT 'en' CHECK (preferred_language IN ('en', 'es', 'pt', 'zh', 'fr', 'de', 'it', 'ja', 'ko'));

-- Criar tabela de traduções de mensagens
CREATE TABLE public.case_messages_translations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.case_messages(id) ON DELETE CASCADE,
  target_language TEXT NOT NULL CHECK (target_language IN ('en', 'es', 'pt', 'zh', 'fr', 'de', 'it', 'ja', 'ko')),
  translated_content TEXT NOT NULL,
  source_language TEXT,
  translation_confidence DECIMAL(3,2),
  translation_provider TEXT DEFAULT 'openai',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índices para performance
CREATE INDEX idx_case_messages_translations_message_id ON public.case_messages_translations(message_id);
CREATE INDEX idx_case_messages_translations_target_language ON public.case_messages_translations(target_language);

-- Adicionar campos de tradução à tabela case_evidence (documentos)
ALTER TABLE public.case_evidence 
ADD COLUMN source_language TEXT,
ADD COLUMN has_translation BOOLEAN DEFAULT FALSE,
ADD COLUMN translated_document_uri TEXT,
ADD COLUMN translation_metadata JSONB DEFAULT '{}';

-- Criar tabela de templates de notificação multilíngue
CREATE TABLE public.notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_key TEXT NOT NULL,
  language TEXT NOT NULL CHECK (language IN ('en', 'es', 'pt', 'zh', 'fr', 'de', 'it', 'ja', 'ko')),
  subject TEXT NOT NULL,
  body TEXT NOT NULL,
  template_type TEXT NOT NULL DEFAULT 'email',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(template_key, language, template_type)
);

-- Inserir templates padrão para notificações
INSERT INTO public.notification_templates (template_key, language, subject, body, template_type) VALUES
-- Inglês
('case_status_update', 'en', 'Case Status Update', 'Your case {{case_title}} has been updated to status: {{status}}', 'email'),
('document_request', 'en', 'Document Request', 'Please upload the following document: {{document_type}}', 'email'),
('rfe_notification', 'en', 'RFE Received', 'We have received an RFE for your case. Please review the requirements.', 'email'),

-- Português
('case_status_update', 'pt', 'Atualização do Status do Caso', 'Seu caso {{case_title}} foi atualizado para o status: {{status}}', 'email'),
('document_request', 'pt', 'Solicitação de Documento', 'Por favor, envie o seguinte documento: {{document_type}}', 'email'),
('rfe_notification', 'pt', 'RFE Recebido', 'Recebemos um RFE para seu caso. Por favor, revise os requisitos.', 'email'),

-- Espanhol
('case_status_update', 'es', 'Actualización del Estado del Caso', 'Su caso {{case_title}} ha sido actualizado al estado: {{status}}', 'email'),
('document_request', 'es', 'Solicitud de Documento', 'Por favor, suba el siguiente documento: {{document_type}}', 'email'),
('rfe_notification', 'es', 'RFE Recibido', 'Hemos recibido un RFE para su caso. Por favor, revise los requisitos.', 'email');

-- RLS policies para as novas tabelas
ALTER TABLE public.case_messages_translations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_templates ENABLE ROW LEVEL SECURITY;

-- Policy para case_messages_translations
CREATE POLICY "Users can view translations for their accessible messages" 
ON public.case_messages_translations 
FOR SELECT 
USING (
  message_id IN (
    SELECT cm.id 
    FROM public.case_messages cm
    JOIN public.cases c ON c.id = cm.case_id
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

CREATE POLICY "System can insert translations" 
ON public.case_messages_translations 
FOR INSERT 
WITH CHECK (true);

-- Policy para notification_templates
CREATE POLICY "Users can view notification templates" 
ON public.notification_templates 
FOR SELECT 
USING (true);

CREATE POLICY "Admins can manage notification templates" 
ON public.notification_templates 
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

-- Trigger para updated_at em notification_templates
CREATE OR REPLACE FUNCTION public.update_notification_templates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_notification_templates_updated_at
  BEFORE UPDATE ON public.notification_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.update_notification_templates_updated_at();

-- Habilitar Realtime para as novas tabelas
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_messages_translations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notification_templates;