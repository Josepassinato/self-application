-- Adicionar novos papéis de usuário
CREATE TYPE public.user_role AS ENUM ('admin', 'lawyer', 'partner', 'client');

-- Adicionar coluna role na tabela profiles se não existir
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'role') THEN
        ALTER TABLE public.profiles ADD COLUMN role public.user_role DEFAULT 'client';
    END IF;
END $$;

-- Criar tabela para log de atividades do caso
CREATE TABLE IF NOT EXISTS public.case_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL,
  user_id UUID NOT NULL,
  action TEXT NOT NULL,
  field_id TEXT,
  old_value JSONB,
  new_value JSONB,
  ai_suggestion BOOLEAN DEFAULT false,
  ip_address INET,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Criar tabela para configurações de parceiros
CREATE TABLE IF NOT EXISTS public.partner_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE,
  require_human_review BOOLEAN DEFAULT true,
  auto_assign_cases BOOLEAN DEFAULT false,
  notification_email TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.case_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partner_settings ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para case_activity_log
CREATE POLICY "Users can view activity logs for their cases" ON public.case_activity_log
FOR SELECT USING (
  case_id IN (
    SELECT c.id FROM public.cases c
    JOIN public.clients cl ON cl.id = c.client_id
    WHERE cl.client_user_id = auth.uid()
       OR cl.responsavel_id = auth.uid()
  ) OR user_id = auth.uid()
);

CREATE POLICY "System can create activity logs" ON public.case_activity_log
FOR INSERT WITH CHECK (true);

-- Políticas RLS para partner_settings
CREATE POLICY "Users can manage their own partner settings" ON public.partner_settings
FOR ALL USING (user_id = auth.uid());

-- Índices
CREATE INDEX IF NOT EXISTS idx_case_activity_log_case_id ON public.case_activity_log(case_id);
CREATE INDEX IF NOT EXISTS idx_case_activity_log_user_id ON public.case_activity_log(user_id);
CREATE INDEX IF NOT EXISTS idx_partner_settings_user_id ON public.partner_settings(user_id);