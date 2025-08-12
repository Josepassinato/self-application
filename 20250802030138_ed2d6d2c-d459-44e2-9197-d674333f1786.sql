-- Criar tabela para rascunhos gerados por AI
CREATE TABLE public.ai_draft_reviews (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  case_id UUID REFERENCES cases(id) ON DELETE CASCADE,
  client_id UUID REFERENCES clients(id) ON DELETE CASCADE,
  draft_type TEXT NOT NULL,
  title TEXT NOT NULL,
  original_content TEXT NOT NULL,
  current_content TEXT NOT NULL,
  ai_metadata JSONB DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'pending',
  priority TEXT NOT NULL DEFAULT 'normal',
  assigned_to UUID REFERENCES auth.users(id),
  reviewed_by UUID REFERENCES auth.users(id),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  due_date TIMESTAMP WITH TIME ZONE,
  notes TEXT
);

-- Criar tabela para logs de revisão
CREATE TABLE public.draft_review_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  draft_id UUID NOT NULL REFERENCES ai_draft_reviews(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  performed_by UUID REFERENCES auth.users(id),
  previous_status TEXT,
  new_status TEXT,
  comments TEXT,
  changes_made JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.ai_draft_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.draft_review_logs ENABLE ROW LEVEL SECURITY;

-- Políticas para ai_draft_reviews
CREATE POLICY "Lawyers can manage drafts in their firm" 
ON public.ai_draft_reviews 
FOR ALL 
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id
  FROM platform_users
  WHERE platform_users.auth_user_id = auth.uid()
));

-- Políticas para draft_review_logs
CREATE POLICY "Lawyers can view logs in their firm" 
ON public.draft_review_logs 
FOR SELECT 
USING (draft_id IN (
  SELECT id FROM ai_draft_reviews 
  WHERE law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
));

CREATE POLICY "Lawyers can create logs in their firm" 
ON public.draft_review_logs 
FOR INSERT 
WITH CHECK (draft_id IN (
  SELECT id FROM ai_draft_reviews 
  WHERE law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
));

-- Triggers para updated_at
CREATE TRIGGER update_ai_draft_reviews_updated_at
BEFORE UPDATE ON public.ai_draft_reviews
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger para criar logs automaticamente
CREATE OR REPLACE FUNCTION public.log_draft_review_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
    INSERT INTO public.draft_review_logs (
      draft_id,
      action,
      performed_by,
      previous_status,
      new_status,
      comments
    ) VALUES (
      NEW.id,
      'status_change',
      auth.uid(),
      OLD.status,
      NEW.status,
      'Status changed from ' || OLD.status || ' to ' || NEW.status
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER log_draft_review_changes
AFTER UPDATE ON public.ai_draft_reviews
FOR EACH ROW
EXECUTE FUNCTION public.log_draft_review_changes();

-- Inserir alguns rascunhos de exemplo para teste
INSERT INTO public.ai_draft_reviews (law_firm_id, draft_type, title, original_content, current_content, status, priority) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'petition', 'Petition I-130 - Maria Silva', 
'PETITION FOR ALIEN RELATIVE

I, John Doe, a U.S. citizen, hereby petition for my spouse Maria Silva to obtain permanent residence in the United States.

Petitioner Information:
- Full Name: John Doe
- Date of Birth: 01/15/1985
- Place of Birth: New York, NY

Beneficiary Information:
- Full Name: Maria Silva
- Date of Birth: 03/22/1987
- Place of Birth: São Paulo, Brazil
- Relationship: Spouse

We were married on June 15, 2020, in Las Vegas, Nevada. I am submitting this petition based on our valid marriage and my status as a U.S. citizen.',

'PETITION FOR ALIEN RELATIVE

I, John Doe, a U.S. citizen, hereby petition for my spouse Maria Silva to obtain permanent residence in the United States.

Petitioner Information:
- Full Name: John Doe
- Date of Birth: 01/15/1985
- Place of Birth: New York, NY

Beneficiary Information:
- Full Name: Maria Silva
- Date of Birth: 03/22/1987
- Place of Birth: São Paulo, Brazil
- Relationship: Spouse

We were married on June 15, 2020, in Las Vegas, Nevada. I am submitting this petition based on our valid marriage and my status as a U.S. citizen.',
'pending', 'high'),

('550e8400-e29b-41d4-a716-446655440001', 'response', 'RFE Response - Carlos Santos', 
'RESPONSE TO REQUEST FOR EVIDENCE

Case Number: MSC2024123456
Petitioner: Carlos Santos
Beneficiary: Ana Santos

Dear Officer,

We hereby submit additional evidence in response to your Request for Evidence dated [DATE]. The following documents are enclosed:

1. Additional proof of relationship
2. Updated financial documentation
3. Medical examination results

We respectfully request that you approve this petition based on the evidence provided.',

'RESPONSE TO REQUEST FOR EVIDENCE

Case Number: MSC2024123456
Petitioner: Carlos Santos
Beneficiary: Ana Santos

Dear Officer,

We hereby submit additional evidence in response to your Request for Evidence dated [DATE]. The following documents are enclosed:

1. Additional proof of relationship
2. Updated financial documentation
3. Medical examination results

We respectfully request that you approve this petition based on the evidence provided.',
'pending', 'urgent'),

('550e8400-e29b-41d4-a716-446655440001', 'letter', 'Cover Letter - Investment Visa', 
'COVER LETTER FOR EB-5 INVESTMENT VISA APPLICATION

Subject: Investment Visa Application for [Investor Name]

Dear USCIS Officer,

Please find enclosed the complete application package for an EB-5 investment visa. The applicant has made a qualifying investment of $800,000 in a TEA project.

Investment Details:
- Investment Amount: $800,000
- Project: Regional Center Project ABC
- Job Creation: Projected 15 direct jobs

Supporting Documentation:
- Form I-526E
- Investment agreements
- Source of funds documentation
- Business plan

We respectfully request approval of this application.',

'COVER LETTER FOR EB-5 INVESTMENT VISA APPLICATION

Subject: Investment Visa Application for [Investor Name]

Dear USCIS Officer,

Please find enclosed the complete application package for an EB-5 investment visa. The applicant has made a qualifying investment of $800,000 in a TEA project.

Investment Details:
- Investment Amount: $800,000
- Project: Regional Center Project ABC
- Job Creation: Projected 15 direct jobs

Supporting Documentation:
- Form I-526E
- Investment agreements
- Source of funds documentation
- Business plan

We respectfully request approval of this application.',
'pending', 'normal');