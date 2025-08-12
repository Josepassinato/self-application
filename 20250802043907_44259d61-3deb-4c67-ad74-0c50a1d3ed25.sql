-- Criar tabelas para sistema de faturamento e cobrança

-- Tabela de faturas/invoices
CREATE TABLE IF NOT EXISTS public.invoices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  subscription_id uuid REFERENCES public.tenant_subscriptions(id),
  stripe_invoice_id text UNIQUE,
  invoice_number text UNIQUE NOT NULL,
  status text NOT NULL DEFAULT 'draft', -- 'draft', 'sent', 'paid', 'overdue', 'cancelled'
  currency text NOT NULL DEFAULT 'BRL',
  subtotal decimal(10,2) NOT NULL DEFAULT 0,
  tax_amount decimal(10,2) NOT NULL DEFAULT 0,
  total_amount decimal(10,2) NOT NULL DEFAULT 0,
  due_date date,
  paid_at timestamp with time zone,
  invoice_pdf_url text,
  billing_period_start date,
  billing_period_end date,
  metadata jsonb DEFAULT '{}',
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabela de pagamentos
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id uuid REFERENCES public.invoices(id) ON DELETE CASCADE,
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  stripe_payment_intent_id text UNIQUE,
  stripe_charge_id text,
  amount decimal(10,2) NOT NULL,
  currency text NOT NULL DEFAULT 'BRL',
  status text NOT NULL DEFAULT 'pending', -- 'pending', 'succeeded', 'failed', 'cancelled', 'refunded'
  payment_method text, -- 'card', 'pix', 'boleto', etc.
  failure_reason text,
  refunded_amount decimal(10,2) DEFAULT 0,
  metadata jsonb DEFAULT '{}',
  processed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabela de eventos de faturamento (para auditoria)
CREATE TABLE IF NOT EXISTS public.billing_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  invoice_id uuid REFERENCES public.invoices(id),
  payment_id uuid REFERENCES public.payments(id),
  subscription_id uuid REFERENCES public.tenant_subscriptions(id),
  event_type text NOT NULL, -- 'invoice_created', 'payment_succeeded', 'subscription_updated', etc.
  stripe_event_id text,
  event_data jsonb DEFAULT '{}',
  processed boolean DEFAULT false,
  error_message text,
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabela para configurações de Stripe por escritório
CREATE TABLE IF NOT EXISTS public.stripe_configurations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE UNIQUE,
  stripe_publishable_key text,
  stripe_webhook_secret text,
  tax_rate decimal(5,2) DEFAULT 0.00, -- Percentual de imposto (ex: 10.50 para 10.5%)
  default_currency text DEFAULT 'BRL',
  invoice_prefix text DEFAULT 'INV-',
  auto_charge boolean DEFAULT true,
  send_receipts boolean DEFAULT true,
  grace_period_days integer DEFAULT 3,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stripe_configurations ENABLE ROW LEVEL SECURITY;

-- Políticas para invoices
CREATE POLICY "Users can view invoices from their firm" ON public.invoices
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage invoices" ON public.invoices
FOR ALL USING (true);

-- Políticas para payments
CREATE POLICY "Users can view payments from their firm" ON public.payments
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage payments" ON public.payments
FOR ALL USING (true);

-- Políticas para billing_events
CREATE POLICY "Users can view billing events from their firm" ON public.billing_events
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage billing events" ON public.billing_events
FOR ALL USING (true);

-- Políticas para stripe_configurations
CREATE POLICY "Admins can manage stripe config for their firm" ON public.stripe_configurations
FOR ALL USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid() 
    AND platform_users.role IN ('admin', 'saas_admin')
  )
);

-- Triggers para updated_at
CREATE TRIGGER update_invoices_updated_at
  BEFORE UPDATE ON public.invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_payments_updated_at
  BEFORE UPDATE ON public.payments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stripe_configurations_updated_at
  BEFORE UPDATE ON public.stripe_configurations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Função para gerar números de faturas sequenciais
CREATE OR REPLACE FUNCTION generate_invoice_number(firm_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  prefix text;
  next_number integer;
  invoice_number text;
BEGIN
  -- Buscar configuração do escritório
  SELECT COALESCE(invoice_prefix, 'INV-') INTO prefix
  FROM stripe_configurations 
  WHERE law_firm_id = firm_id;
  
  -- Se não encontrar configuração, usar padrão
  IF prefix IS NULL THEN
    prefix := 'INV-';
  END IF;
  
  -- Buscar próximo número sequencial para o escritório
  SELECT COALESCE(MAX(
    CASE 
      WHEN invoice_number ~ (prefix || '[0-9]+$') 
      THEN CAST(SUBSTRING(invoice_number FROM LENGTH(prefix) + 1) AS INTEGER)
      ELSE 0 
    END
  ), 0) + 1 INTO next_number
  FROM invoices 
  WHERE law_firm_id = firm_id;
  
  -- Gerar número da fatura com padding de zeros
  invoice_number := prefix || LPAD(next_number::text, 6, '0');
  
  RETURN invoice_number;
END;
$$;