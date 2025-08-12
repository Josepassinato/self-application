-- Expandir tabela document_analyses para incluir campos de auditoria
ALTER TABLE public.document_analyses 
ADD COLUMN IF NOT EXISTS prompt_version TEXT,
ADD COLUMN IF NOT EXISTS llm_response JSONB,
ADD COLUMN IF NOT EXISTS lawyer_user_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS prompt_template_id UUID REFERENCES prompt_templates(id),
ADD COLUMN IF NOT EXISTS model_used TEXT,
ADD COLUMN IF NOT EXISTS processing_time_ms INTEGER,
ADD COLUMN IF NOT EXISTS tokens_used INTEGER,
ADD COLUMN IF NOT EXISTS confidence_score DECIMAL(3,2),
ADD COLUMN IF NOT EXISTS analysis_context JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS reviewed_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS review_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS review_comments TEXT;

-- Criar índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_document_analyses_lawyer_user ON document_analyses(lawyer_user_id);
CREATE INDEX IF NOT EXISTS idx_document_analyses_created_at ON document_analyses(created_at);
CREATE INDEX IF NOT EXISTS idx_document_analyses_prompt_template ON document_analyses(prompt_template_id);
CREATE INDEX IF NOT EXISTS idx_document_analyses_review_status ON document_analyses(review_status);

-- Criar tabela para auditoria detalhada de análises de documentos
CREATE TABLE IF NOT EXISTS public.document_analysis_audit (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  analysis_id UUID NOT NULL REFERENCES document_analyses(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  performed_by UUID REFERENCES auth.users(id),
  previous_data JSONB,
  new_data JSONB,
  changes_summary TEXT,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- RLS para tabela de auditoria
ALTER TABLE public.document_analysis_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lawyers can view audit logs for their firm" 
ON public.document_analysis_audit 
FOR SELECT 
USING (analysis_id IN (
  SELECT id FROM document_analyses da 
  WHERE da.lawyer_user_id IN (
    SELECT auth_user_id FROM platform_users 
    WHERE law_firm_id IN (
      SELECT law_firm_id FROM platform_users 
      WHERE auth_user_id = auth.uid()
    )
  )
));

CREATE POLICY "System can create audit logs" 
ON public.document_analysis_audit 
FOR INSERT 
WITH CHECK (true);

-- Trigger para criar logs de auditoria automaticamente
CREATE OR REPLACE FUNCTION public.audit_document_analysis_changes()
RETURNS TRIGGER AS $$
DECLARE
  changes_summary TEXT := '';
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Detectar mudanças principais
    IF OLD.review_status != NEW.review_status THEN
      changes_summary := changes_summary || 'Status: ' || OLD.review_status || ' → ' || NEW.review_status || '; ';
    END IF;
    
    IF OLD.reviewed_by != NEW.reviewed_by OR (OLD.reviewed_by IS NULL AND NEW.reviewed_by IS NOT NULL) THEN
      changes_summary := changes_summary || 'Revisor alterado; ';
    END IF;
    
    IF OLD.review_comments != NEW.review_comments OR (OLD.review_comments IS NULL AND NEW.review_comments IS NOT NULL) THEN
      changes_summary := changes_summary || 'Comentários atualizados; ';
    END IF;

    INSERT INTO public.document_analysis_audit (
      analysis_id,
      action,
      performed_by,
      previous_data,
      new_data,
      changes_summary
    ) VALUES (
      NEW.id,
      'updated',
      auth.uid(),
      to_jsonb(OLD),
      to_jsonb(NEW),
      TRIM('; ' FROM changes_summary)
    );
    
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.document_analysis_audit (
      analysis_id,
      action,
      performed_by,
      previous_data,
      changes_summary
    ) VALUES (
      OLD.id,
      'deleted',
      auth.uid(),
      to_jsonb(OLD),
      'Document analysis deleted'
    );
    
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO public.document_analysis_audit (
      analysis_id,
      action,
      performed_by,
      new_data,
      changes_summary
    ) VALUES (
      NEW.id,
      'created',
      auth.uid(),
      to_jsonb(NEW),
      'Document analysis created'
    );
    
    RETURN NEW;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER audit_document_analysis_changes
AFTER INSERT OR UPDATE OR DELETE ON public.document_analyses
FOR EACH ROW
EXECUTE FUNCTION public.audit_document_analysis_changes();

-- Criar view para relatórios de auditoria
CREATE OR REPLACE VIEW public.document_analysis_audit_report AS
SELECT 
  daa.id,
  daa.analysis_id,
  da.document_type,
  da.analysis_type,
  daa.action,
  daa.performed_by,
  pu.first_name || ' ' || pu.last_name as performed_by_name,
  pu.email as performed_by_email,
  daa.changes_summary,
  daa.created_at,
  da.created_at as analysis_created_at,
  lawyer_pu.first_name || ' ' || lawyer_pu.last_name as lawyer_name,
  lawyer_pu.email as lawyer_email
FROM document_analysis_audit daa
LEFT JOIN document_analyses da ON daa.analysis_id = da.id
LEFT JOIN platform_users pu ON daa.performed_by = pu.auth_user_id
LEFT JOIN platform_users lawyer_pu ON da.lawyer_user_id = lawyer_pu.auth_user_id
ORDER BY daa.created_at DESC;