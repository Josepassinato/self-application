-- Adicionar campos de personalização para law_firms
ALTER TABLE public.law_firms 
ADD COLUMN IF NOT EXISTS logo_url TEXT,
ADD COLUMN IF NOT EXISTS primary_color TEXT DEFAULT '#2563eb',
ADD COLUMN IF NOT EXISTS secondary_color TEXT DEFAULT '#1e40af',
ADD COLUMN IF NOT EXISTS website TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS address TEXT,
ADD COLUMN IF NOT EXISTS description TEXT;

-- Adicionar configurações de email para cada escritório
CREATE TABLE IF NOT EXISTS public.law_firm_email_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  sender_name TEXT NOT NULL DEFAULT 'Escritório',
  sender_email TEXT NOT NULL,
  reply_to_email TEXT,
  smtp_host TEXT,
  smtp_port INTEGER,
  smtp_username TEXT,
  smtp_password TEXT,
  use_custom_smtp BOOLEAN DEFAULT false,
  email_signature TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(law_firm_id)
);

-- Habilitar RLS na nova tabela
ALTER TABLE public.law_firm_email_settings ENABLE ROW LEVEL SECURITY;

-- Política para permitir que usuários do escritório gerenciem as configurações de email
CREATE POLICY "Users can manage their firm's email settings"
ON public.law_firm_email_settings
FOR ALL
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id
  FROM platform_users
  WHERE platform_users.auth_user_id = auth.uid()
));

-- Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_law_firm_email_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_law_firm_email_settings_updated_at
  BEFORE UPDATE ON public.law_firm_email_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_law_firm_email_settings_updated_at();