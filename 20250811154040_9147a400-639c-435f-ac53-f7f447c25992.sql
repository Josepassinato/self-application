-- Criar tabelas necessárias para o portal do cliente

-- Tabela de mensagens do caso
CREATE TABLE IF NOT EXISTS public.case_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES auth.users(id),
  sender_type TEXT NOT NULL DEFAULT 'team', -- 'client' ou 'team'
  message TEXT NOT NULL,
  attachments JSONB DEFAULT '[]'::jsonb,
  read_by JSONB DEFAULT '[]'::jsonb, -- array de user_ids que leram
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Criar trigger para updated_at
CREATE TRIGGER update_case_messages_updated_at
  BEFORE UPDATE ON public.case_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Habilitar RLS
ALTER TABLE public.case_messages ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_messages
CREATE POLICY "Clientes podem ver mensagens do seu caso"
  ON public.case_messages FOR SELECT
  USING (
    case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      WHERE cl.client_user_id = auth.uid()
    )
  );

CREATE POLICY "Clientes podem enviar mensagens no seu caso"
  ON public.case_messages FOR INSERT
  WITH CHECK (
    case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      WHERE cl.client_user_id = auth.uid()
    )
    AND sender_id = auth.uid()
    AND sender_type = 'client'
  );

CREATE POLICY "Equipe pode ver mensagens dos casos da firma"
  ON public.case_messages FOR SELECT
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

CREATE POLICY "Equipe pode enviar mensagens nos casos da firma"
  ON public.case_messages FOR INSERT
  WITH CHECK (
    case_id IN (
      SELECT c.id FROM public.cases c
      JOIN public.clients cl ON cl.id = c.client_id
      JOIN public.platform_users pu ON pu.law_firm_id IN (
        SELECT resp.law_firm_id FROM public.platform_users resp
        WHERE resp.auth_user_id = cl.responsavel_id
      )
      WHERE pu.auth_user_id = auth.uid()
    )
    AND sender_id = auth.uid()
    AND sender_type = 'team'
  );

-- Tabela para evidências do caso (se não existir)
CREATE TABLE IF NOT EXISTS public.case_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
  rfe_id UUID REFERENCES public.case_rfe(id),
  evidence_type TEXT NOT NULL,
  document_uri TEXT,
  description TEXT,
  status TEXT DEFAULT 'pending',
  uploaded_by TEXT DEFAULT 'client', -- 'client' ou 'team'
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

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

-- Tabela para notificações do cliente
CREATE TABLE IF NOT EXISTS public.client_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT NOT NULL, -- 'status_change', 'rfe_request', 'deadline_reminder', etc.
  priority TEXT DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
  read_at TIMESTAMP WITH TIME ZONE,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.client_notifications ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para client_notifications
CREATE POLICY "Clientes podem ver suas notificações"
  ON public.client_notifications FOR SELECT
  USING (
    client_id IN (
      SELECT cl.id FROM public.clients cl
      WHERE cl.client_user_id = auth.uid()
    )
  );

CREATE POLICY "Clientes podem marcar notificações como lidas"
  ON public.client_notifications FOR UPDATE
  USING (
    client_id IN (
      SELECT cl.id FROM public.clients cl
      WHERE cl.client_user_id = auth.uid()
    )
  )
  WITH CHECK (
    client_id IN (
      SELECT cl.id FROM public.clients cl
      WHERE cl.client_user_id = auth.uid()
    )
  );

CREATE POLICY "Sistema pode criar notificações"
  ON public.client_notifications FOR INSERT
  WITH CHECK (true);

-- Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_case_messages_case_id ON public.case_messages(case_id);
CREATE INDEX IF NOT EXISTS idx_case_messages_created_at ON public.case_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_case_evidence_case_id ON public.case_evidence(case_id);
CREATE INDEX IF NOT EXISTS idx_client_notifications_client_id ON public.client_notifications(client_id);
CREATE INDEX IF NOT EXISTS idx_client_notifications_read_at ON public.client_notifications(read_at);

-- Habilitar realtime para as tabelas
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.case_evidence;
ALTER PUBLICATION supabase_realtime ADD TABLE public.client_notifications;