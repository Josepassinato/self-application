-- Criar tabela document_audit para rastrear assinaturas e ações de documento
CREATE TABLE public.document_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id UUID NOT NULL,
  action_type TEXT NOT NULL, -- 'signature_requested', 'signature_completed', 'approved', 'rejected'
  performed_by UUID,
  signature_url TEXT,
  docusign_envelope_id TEXT,
  docusign_status TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.document_audit ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para document_audit
CREATE POLICY "Users can view document audit from their firm documents" 
ON public.document_audit 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.case_documents cd
    JOIN public.cases c ON c.id = cd.case_id
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE cd.id = document_audit.document_id
      AND pu.law_firm_id IN (
        SELECT responsavel.law_firm_id
        FROM public.platform_users responsavel
        WHERE responsavel.auth_user_id = cl.responsavel_id
      )
  )
);

CREATE POLICY "System can create document audit entries" 
ON public.document_audit 
FOR INSERT 
WITH CHECK (true);

-- Índices para melhor performance
CREATE INDEX idx_document_audit_document_id ON public.document_audit(document_id);
CREATE INDEX idx_document_audit_envelope_id ON public.document_audit(docusign_envelope_id);
CREATE INDEX idx_document_audit_created_at ON public.document_audit(created_at);