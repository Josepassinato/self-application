-- Criar tabela de planos do SaaS
CREATE TABLE IF NOT EXISTS public.saas_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT,
  price_monthly DECIMAL(10,2) NOT NULL DEFAULT 0,
  price_yearly DECIMAL(10,2) NOT NULL DEFAULT 0,
  features JSONB DEFAULT '[]'::jsonb,
  limits JSONB DEFAULT '{}'::jsonb, -- Ex: {"users": 5, "documents_per_month": 100, "storage_gb": 10}
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Criar tabela de assinaturas dos escritórios
CREATE TABLE IF NOT EXISTS public.tenant_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  plan_id uuid NOT NULL REFERENCES public.saas_plans(id),
  status TEXT NOT NULL DEFAULT 'trial', -- 'trial', 'active', 'suspended', 'cancelled'
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  current_period_start TIMESTAMP WITH TIME ZONE,
  current_period_end TIMESTAMP WITH TIME ZONE,
  stripe_subscription_id TEXT,
  stripe_customer_id TEXT,
  billing_cycle TEXT DEFAULT 'monthly', -- 'monthly', 'yearly'
  usage_tracking JSONB DEFAULT '{}'::jsonb, -- Track current usage against limits
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  UNIQUE(law_firm_id)
);

-- Criar tabela de convites de onboarding
CREATE TABLE IF NOT EXISTS public.tenant_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL,
  law_firm_name TEXT NOT NULL,
  plan_id uuid NOT NULL REFERENCES public.saas_plans(id),
  invitation_token uuid DEFAULT gen_random_uuid(),
  invited_by uuid REFERENCES auth.users(id),
  status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'expired'
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + INTERVAL '7 days'),
  accepted_at TIMESTAMP WITH TIME ZONE,
  law_firm_id uuid REFERENCES public.law_firms(id),
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Criar tabela de logs de onboarding
CREATE TABLE IF NOT EXISTS public.onboarding_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid REFERENCES public.law_firms(id),
  invitation_id uuid REFERENCES public.tenant_invitations(id),
  step TEXT NOT NULL, -- 'invitation_sent', 'firm_created', 'user_created', 'welcome_email_sent'
  status TEXT NOT NULL, -- 'success', 'failed', 'pending'
  details JSONB DEFAULT '{}'::jsonb,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Habilitar RLS nas novas tabelas
ALTER TABLE public.saas_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.onboarding_logs ENABLE ROW LEVEL SECURITY;

-- Políticas para saas_plans (público para leitura)
CREATE POLICY "Anyone can view active plans" ON public.saas_plans
FOR SELECT USING (is_active = true);

CREATE POLICY "Only SaaS admins can manage plans" ON public.saas_plans
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'saas_admin'
  )
);

-- Políticas para tenant_subscriptions
CREATE POLICY "Users can view their firm subscription" ON public.tenant_subscriptions
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage subscriptions" ON public.tenant_subscriptions
FOR ALL USING (true);

-- Políticas para tenant_invitations (apenas sistema pode gerenciar)
CREATE POLICY "System can manage invitations" ON public.tenant_invitations
FOR ALL USING (true);

-- Políticas para onboarding_logs
CREATE POLICY "SaaS admins can view logs" ON public.onboarding_logs
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'saas_admin'
  )
);

CREATE POLICY "System can create logs" ON public.onboarding_logs
FOR INSERT WITH CHECK (true);

-- Inserir planos padrão
INSERT INTO public.saas_plans (name, display_name, description, price_monthly, price_yearly, features, limits, sort_order) VALUES
('starter', 'Plano Starter', 'Ideal para escritórios pequenos começando na digitalização', 97.00, 970.00, 
 '["Até 3 usuários", "100 documentos/mês", "Suporte por email", "Templates básicos"]'::jsonb,
 '{"users": 3, "documents_per_month": 100, "storage_gb": 5, "ai_analysis_per_month": 50}'::jsonb, 1),

('professional', 'Plano Professional', 'Para escritórios estabelecidos com demanda média', 297.00, 2970.00,
 '["Até 10 usuários", "500 documentos/mês", "Suporte prioritário", "Templates avançados", "Integrações básicas", "DocuSign incluído"]'::jsonb,
 '{"users": 10, "documents_per_month": 500, "storage_gb": 25, "ai_analysis_per_month": 200, "docusign_envelopes_per_month": 100}'::jsonb, 2),

('enterprise', 'Plano Enterprise', 'Solução completa para grandes escritórios', 697.00, 6970.00,
 '["Usuários ilimitados", "Documentos ilimitados", "Suporte 24/7", "White-label", "Integrações avançadas", "API dedicada", "SLA garantido"]'::jsonb,
 '{"users": -1, "documents_per_month": -1, "storage_gb": 500, "ai_analysis_per_month": -1, "docusign_envelopes_per_month": -1}'::jsonb, 3);

-- Triggers para updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_saas_plans_updated_at
  BEFORE UPDATE ON public.saas_plans
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tenant_subscriptions_updated_at
  BEFORE UPDATE ON public.tenant_subscriptions
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_tenant_invitations_updated_at
  BEFORE UPDATE ON public.tenant_invitations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();