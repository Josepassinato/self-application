-- Create billing_accounts table
CREATE TABLE public.billing_accounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL,
  stripe_customer_id TEXT,
  paypal_customer_id TEXT,
  default_currency TEXT DEFAULT 'USD',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create billing_invoices table
CREATE TABLE public.billing_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES billing_accounts(id) ON DELETE CASCADE,
  case_id UUID REFERENCES cases(id),
  amount_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'USD',
  description TEXT,
  status TEXT DEFAULT 'pending', -- pending|paid|failed|refunded
  due_date DATE,
  paid_at TIMESTAMP WITH TIME ZONE,
  stripe_invoice_id TEXT,
  paypal_invoice_id TEXT,
  payment_link TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create billing_payouts table
CREATE TABLE public.billing_payouts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL,
  amount_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'USD',
  period_start DATE,
  period_end DATE,
  status TEXT DEFAULT 'pending', -- pending|paid|failed
  paid_at TIMESTAMP WITH TIME ZONE,
  stripe_payout_id TEXT,
  paypal_payout_id TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create billing_transactions table for tracking all transactions
CREATE TABLE public.billing_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id UUID NOT NULL REFERENCES billing_accounts(id),
  invoice_id UUID REFERENCES billing_invoices(id),
  payout_id UUID REFERENCES billing_payouts(id),
  transaction_type TEXT NOT NULL, -- payment|refund|payout|fee
  amount_cents INTEGER NOT NULL,
  currency TEXT DEFAULT 'USD',
  provider TEXT NOT NULL, -- stripe|paypal
  provider_transaction_id TEXT,
  status TEXT DEFAULT 'pending',
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.billing_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_transactions ENABLE ROW LEVEL SECURITY;

-- RLS Policies for billing_accounts
CREATE POLICY "Users can manage their firm's billing accounts" 
ON public.billing_accounts 
FOR ALL 
USING (partner_id IN (
  SELECT pu.auth_user_id 
  FROM platform_users pu 
  WHERE pu.law_firm_id IN (
    SELECT platform_users.law_firm_id 
    FROM platform_users 
    WHERE platform_users.auth_user_id = auth.uid()
  )
));

-- RLS Policies for billing_invoices
CREATE POLICY "Users can view invoices for their firm" 
ON public.billing_invoices 
FOR SELECT 
USING (account_id IN (
  SELECT ba.id 
  FROM billing_accounts ba 
  WHERE ba.partner_id IN (
    SELECT pu.auth_user_id 
    FROM platform_users pu 
    WHERE pu.law_firm_id IN (
      SELECT platform_users.law_firm_id 
      FROM platform_users 
      WHERE platform_users.auth_user_id = auth.uid()
    )
  )
));

CREATE POLICY "System can manage invoices" 
ON public.billing_invoices 
FOR ALL 
USING (true);

-- RLS Policies for billing_payouts
CREATE POLICY "Partners can view their payouts" 
ON public.billing_payouts 
FOR SELECT 
USING (partner_id = auth.uid() OR partner_id IN (
  SELECT pu.auth_user_id 
  FROM platform_users pu 
  WHERE pu.law_firm_id IN (
    SELECT platform_users.law_firm_id 
    FROM platform_users 
    WHERE platform_users.auth_user_id = auth.uid()
  )
));

CREATE POLICY "System can manage payouts" 
ON public.billing_payouts 
FOR ALL 
USING (true);

-- RLS Policies for billing_transactions
CREATE POLICY "Users can view transactions for their firm" 
ON public.billing_transactions 
FOR SELECT 
USING (account_id IN (
  SELECT ba.id 
  FROM billing_accounts ba 
  WHERE ba.partner_id IN (
    SELECT pu.auth_user_id 
    FROM platform_users pu 
    WHERE pu.law_firm_id IN (
      SELECT platform_users.law_firm_id 
      FROM platform_users 
      WHERE platform_users.auth_user_id = auth.uid()
    )
  )
));

CREATE POLICY "System can manage transactions" 
ON public.billing_transactions 
FOR ALL 
USING (true);

-- Create indexes for performance
CREATE INDEX idx_billing_accounts_partner_id ON billing_accounts(partner_id);
CREATE INDEX idx_billing_invoices_account_id ON billing_invoices(account_id);
CREATE INDEX idx_billing_invoices_status ON billing_invoices(status);
CREATE INDEX idx_billing_invoices_due_date ON billing_invoices(due_date);
CREATE INDEX idx_billing_payouts_partner_id ON billing_payouts(partner_id);
CREATE INDEX idx_billing_payouts_status ON billing_payouts(status);
CREATE INDEX idx_billing_transactions_account_id ON billing_transactions(account_id);

-- Create function to update updated_at columns
CREATE OR REPLACE FUNCTION update_billing_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_billing_accounts_updated_at
  BEFORE UPDATE ON billing_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_billing_updated_at();

CREATE TRIGGER update_billing_invoices_updated_at
  BEFORE UPDATE ON billing_invoices
  FOR EACH ROW
  EXECUTE FUNCTION update_billing_updated_at();

CREATE TRIGGER update_billing_payouts_updated_at
  BEFORE UPDATE ON billing_payouts
  FOR EACH ROW
  EXECUTE FUNCTION update_billing_updated_at();