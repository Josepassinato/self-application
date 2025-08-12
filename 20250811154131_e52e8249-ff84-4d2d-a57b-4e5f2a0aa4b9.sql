-- Corrigir tabelas para o portal do cliente

-- Primeiro, verificar se case_evidence já existe e corrigir
DROP TABLE IF EXISTS public.case_evidence CASCADE;

-- Criar tabela case_evidence corretamente
CREATE TABLE public.case_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  rfe_id UUID,
  evidence_type TEXT NOT NULL,
  document_uri TEXT,
  description TEXT,
  status TEXT DEFAULT 'pending',
  uploaded_by TEXT DEFAULT 'client', -- 'client' ou 'team'
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Criar trigger para updated_at
CREATE TRIGGER update_case_evidence_updated_at
  BEFORE UPDATE ON public.case_evidence
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Habilitar RLS para case_evidence
ALTER TABLE public.case_evidence ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_evidence
CREATE POLICY "Clientes podem ver evidências do seu caso"
  ON public.case_evidence FOR SELECT
  USING (
    case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      WHERE cl.client_user_id = auth.uid()
    )
  );

CREATE POLICY "Clientes podem criar evidências no seu caso"
  ON public.case_evidence FOR INSERT
  WITH CHECK (
    case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      WHERE cl.client_user_id = auth.uid()
    )
    AND uploaded_by = 'client'
  );

CREATE POLICY "Equipe pode gerenciar evidências dos casos da firma"
  ON public.case_evidence FOR ALL
  USING (
    case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      JOIN public.platform_users pu ON pu.law_firm_id IN (
        SELECT resp.law_firm_id FROM public.platform_users resp
        WHERE resp.auth_user_id = cl.responsavel_id
      )
      WHERE pu.auth_user_id = auth.uid()
    )
  );

-- Criar índices adicionais
CREATE INDEX IF NOT EXISTS idx_case_evidence_case_id ON public.case_evidence(case_id);
CREATE INDEX IF NOT EXISTS idx_case_evidence_uploaded_by ON public.case_evidence(uploaded_by);

-- Habilitar realtime para case_evidence
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_evidence;