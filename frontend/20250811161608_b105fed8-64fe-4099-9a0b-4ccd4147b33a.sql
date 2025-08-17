-- Criar tabela para protocolos de e-filing
CREATE TABLE public.case_efiling (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  form_type TEXT NOT NULL, -- I-130, I-485, etc.
  submission_channel TEXT NOT NULL, -- uscis_api, secure_email, portal_automation
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'submitted', 'accepted', 'rejected', 'processing', 'requires_action')),
  protocol_number TEXT, -- receipt number do USCIS
  submitted_at TIMESTAMP WITH TIME ZONE,
  response_json JSONB,
  package_url TEXT, -- URL do pacote gerado
  digital_signature TEXT, -- hash da assinatura digital
  retry_count INTEGER DEFAULT 0,
  last_error TEXT,
  expires_at TIMESTAMP WITH TIME ZONE, -- para sessões que expiram
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela para histórico de submissões e status
CREATE TABLE public.efiling_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  efiling_id UUID NOT NULL REFERENCES public.case_efiling(id) ON DELETE CASCADE,
  previous_status TEXT,
  new_status TEXT NOT NULL,
  status_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  details JSONB,
  source TEXT NOT NULL DEFAULT 'system', -- system, uscis_api, manual
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela para configurações de canais de submissão
CREATE TABLE public.submission_channels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  channel_type TEXT NOT NULL, -- uscis_api, secure_email, portal_automation
  channel_config JSONB NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  priority INTEGER DEFAULT 0, -- para ordem de tentativa
  supported_forms TEXT[] DEFAULT '{}', -- tipos de formulário suportados
  rate_limit INTEGER DEFAULT 100, -- requests por hora
  timeout_seconds INTEGER DEFAULT 300,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar tabela para pacotes de submissão
CREATE TABLE public.submission_packages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  package_name TEXT NOT NULL,
  package_url TEXT, -- storage bucket URL
  package_size BIGINT, -- tamanho em bytes
  file_count INTEGER DEFAULT 0,
  checksum TEXT, -- para verificação de integridade
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '30 days')
);

-- Criar índices para performance
CREATE INDEX idx_case_efiling_case_id ON public.case_efiling(case_id);
CREATE INDEX idx_case_efiling_status ON public.case_efiling(status);
CREATE INDEX idx_case_efiling_form_type ON public.case_efiling(form_type);
CREATE INDEX idx_case_efiling_submitted_at ON public.case_efiling(submitted_at);
CREATE INDEX idx_efiling_status_history_efiling_id ON public.efiling_status_history(efiling_id);
CREATE INDEX idx_submission_channels_law_firm_id ON public.submission_channels(law_firm_id);
CREATE INDEX idx_submission_packages_case_id ON public.submission_packages(case_id);

-- Habilitar RLS
ALTER TABLE public.case_efiling ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.efiling_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submission_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submission_packages ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_efiling
CREATE POLICY "Users can view e-filing for their accessible cases" 
ON public.case_efiling 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
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

CREATE POLICY "Users can manage e-filing for their accessible cases" 
ON public.case_efiling 
FOR ALL
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
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
)
WITH CHECK (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
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

-- Políticas para efiling_status_history
CREATE POLICY "Users can view status history for accessible e-filing" 
ON public.efiling_status_history 
FOR SELECT 
USING (
  efiling_id IN (
    SELECT ef.id 
    FROM public.case_efiling ef
    JOIN public.cases c ON c.id = ef.case_id
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

CREATE POLICY "System can manage status history" 
ON public.efiling_status_history 
FOR ALL
USING (true)
WITH CHECK (true);

-- Políticas para submission_channels
CREATE POLICY "Users can manage channels for their firm" 
ON public.submission_channels 
FOR ALL
USING (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
  )
)
WITH CHECK (
  law_firm_id IN (
    SELECT pu.law_firm_id
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
  )
);

-- Políticas para submission_packages
CREATE POLICY "Users can view packages for their accessible cases" 
ON public.submission_packages 
FOR SELECT 
USING (
  case_id IN (
    SELECT c.id 
    FROM public.cases c
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

CREATE POLICY "System can manage packages" 
ON public.submission_packages 
FOR ALL
USING (true)
WITH CHECK (true);

-- Triggers para updated_at
CREATE OR REPLACE FUNCTION public.update_case_efiling_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_case_efiling_updated_at
  BEFORE UPDATE ON public.case_efiling
  FOR EACH ROW
  EXECUTE FUNCTION public.update_case_efiling_updated_at();

CREATE OR REPLACE FUNCTION public.update_submission_channels_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE TRIGGER update_submission_channels_updated_at
  BEFORE UPDATE ON public.submission_channels
  FOR EACH ROW
  EXECUTE FUNCTION public.update_submission_channels_updated_at();

-- Trigger para criar histórico automaticamente
CREATE OR REPLACE FUNCTION public.log_efiling_status_change()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
    INSERT INTO public.efiling_status_history (
      efiling_id,
      previous_status,
      new_status,
      details,
      source
    ) VALUES (
      NEW.id,
      OLD.status,
      NEW.status,
      jsonb_build_object(
        'protocol_number', NEW.protocol_number,
        'submission_channel', NEW.submission_channel,
        'retry_count', NEW.retry_count
      ),
      'system'
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER log_efiling_status_change
  AFTER UPDATE ON public.case_efiling
  FOR EACH ROW
  EXECUTE FUNCTION public.log_efiling_status_change();

-- Habilitar Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_efiling;
ALTER PUBLICATION supabase_realtime ADD TABLE public.efiling_status_history;