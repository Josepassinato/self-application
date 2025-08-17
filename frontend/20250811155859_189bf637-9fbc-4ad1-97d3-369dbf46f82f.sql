-- Criar tabela case_messages (precisa existir primeiro)
CREATE TABLE public.case_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('client', 'team')),
  message TEXT NOT NULL,
  attachments JSONB DEFAULT '[]',
  read_by UUID[] DEFAULT '{}',
  is_translated BOOLEAN DEFAULT FALSE,
  source_language TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índices para performance
CREATE INDEX idx_case_messages_case_id ON public.case_messages(case_id);
CREATE INDEX idx_case_messages_sender_id ON public.case_messages(sender_id);
CREATE INDEX idx_case_messages_created_at ON public.case_messages(created_at);

-- Habilitar RLS
ALTER TABLE public.case_messages ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_messages
CREATE POLICY "Users can view messages for their accessible cases" 
ON public.case_messages 
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

CREATE POLICY "Users can send messages to their accessible cases" 
ON public.case_messages 
FOR INSERT 
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

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION public.update_case_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_case_messages_updated_at
  BEFORE UPDATE ON public.case_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.update_case_messages_updated_at();

-- Habilitar Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_messages;