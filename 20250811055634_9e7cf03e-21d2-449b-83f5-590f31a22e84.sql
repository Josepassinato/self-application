-- Create case_rfe table for RFE/NOID notifications
CREATE TABLE IF NOT EXISTS public.case_rfe (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('RFE', 'NOID')),
  form_code TEXT,
  summary TEXT,
  due_date DATE,
  full_text TEXT,
  document_uri TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'responded', 'overdue')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  analyzed_at TIMESTAMPTZ,
  evidence_checklist JSONB DEFAULT '[]'::jsonb,
  response_draft TEXT,
  submitted_at TIMESTAMPTZ,
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Create case_evidence table to track evidence documents
CREATE TABLE IF NOT EXISTS public.case_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  rfe_id UUID REFERENCES public.case_rfe(id) ON DELETE SET NULL,
  evidence_type TEXT NOT NULL,
  description TEXT,
  document_uri TEXT,
  status TEXT DEFAULT 'available' CHECK (status IN ('available', 'missing', 'needs_update')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  metadata JSONB DEFAULT '{}'::jsonb
);

-- Enable RLS
ALTER TABLE public.case_rfe ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.case_evidence ENABLE ROW LEVEL SECURITY;

-- RLS Policies for case_rfe
CREATE POLICY "Users can view RFE/NOID for their firm cases"
ON public.case_rfe
FOR SELECT
USING (
  case_id IN (
    SELECT c.id
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage case RFE records"
ON public.case_rfe
FOR ALL
USING (true);

-- RLS Policies for case_evidence
CREATE POLICY "Users can view evidence for their firm cases"
ON public.case_evidence
FOR SELECT
USING (
  case_id IN (
    SELECT c.id
    FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
    WHERE pu.law_firm_id IN (
      SELECT resp.law_firm_id 
      FROM public.platform_users resp 
      WHERE resp.auth_user_id = cl.responsavel_id
    )
  )
);

CREATE POLICY "System can manage case evidence records"
ON public.case_evidence
FOR ALL
USING (true);

-- Add updated_at trigger for case_rfe
CREATE TRIGGER update_case_rfe_updated_at
  BEFORE UPDATE ON public.case_rfe
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Add updated_at trigger for case_evidence
CREATE TRIGGER update_case_evidence_updated_at
  BEFORE UPDATE ON public.case_evidence
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Indexes for performance
CREATE INDEX idx_case_rfe_case_id ON public.case_rfe(case_id);
CREATE INDEX idx_case_rfe_type ON public.case_rfe(type);
CREATE INDEX idx_case_rfe_status ON public.case_rfe(status);
CREATE INDEX idx_case_rfe_due_date ON public.case_rfe(due_date);
CREATE INDEX idx_case_evidence_case_id ON public.case_evidence(case_id);
CREATE INDEX idx_case_evidence_rfe_id ON public.case_evidence(rfe_id);
CREATE INDEX idx_case_evidence_type ON public.case_evidence(evidence_type);