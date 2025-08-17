-- Criar tabela para armazenar regras de política do USCIS
CREATE TABLE public.policy_rules (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID REFERENCES law_firms(id) ON DELETE CASCADE,
  rule_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  content TEXT NOT NULL,
  source_url TEXT NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'uscis',
  format_type TEXT NOT NULL, -- 'xml', 'json', 'html'
  effective_date DATE NOT NULL,
  published_date DATE,
  last_updated DATE,
  status TEXT NOT NULL DEFAULT 'active',
  category TEXT,
  subcategory TEXT,
  impact_level TEXT, -- 'low', 'medium', 'high', 'critical'
  affected_forms JSONB DEFAULT '[]',
  affected_processes JSONB DEFAULT '[]',
  raw_data JSONB,
  checksum TEXT, -- Para detectar mudanças
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(rule_id, source_type)
);

-- Criar tabela para logs de coleta
CREATE TABLE public.policy_collection_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID REFERENCES law_firms(id) ON DELETE CASCADE,
  collection_type TEXT NOT NULL, -- 'manual', 'scheduled', 'webhook'
  source_url TEXT NOT NULL,
  status TEXT NOT NULL, -- 'success', 'error', 'partial'
  rules_found INTEGER DEFAULT 0,
  rules_new INTEGER DEFAULT 0,
  rules_updated INTEGER DEFAULT 0,
  execution_time_ms INTEGER,
  error_message TEXT,
  metadata JSONB DEFAULT '{}',
  started_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE,
  performed_by UUID REFERENCES auth.users(id)
);

-- Criar tabela para configurações de coleta
CREATE TABLE public.policy_collection_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES law_firms(id) ON DELETE CASCADE,
  source_name TEXT NOT NULL,
  source_url TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  collection_frequency TEXT NOT NULL DEFAULT 'daily', -- 'hourly', 'daily', 'weekly'
  last_collection_at TIMESTAMP WITH TIME ZONE,
  next_collection_at TIMESTAMP WITH TIME ZONE,
  filters JSONB DEFAULT '{}',
  headers JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(law_firm_id, source_name)
);

-- Habilitar RLS
ALTER TABLE public.policy_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_collection_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_collection_settings ENABLE ROW LEVEL SECURITY;

-- Políticas RLS para policy_rules
CREATE POLICY "Users can view rules from their firm" 
ON public.policy_rules 
FOR SELECT 
USING (law_firm_id IN (
  SELECT law_firm_id FROM platform_users 
  WHERE auth_user_id = auth.uid()
));

CREATE POLICY "System can manage all rules" 
ON public.policy_rules 
FOR ALL 
USING (true);

-- Políticas RLS para policy_collection_logs
CREATE POLICY "Users can view collection logs from their firm" 
ON public.policy_collection_logs 
FOR SELECT 
USING (law_firm_id IN (
  SELECT law_firm_id FROM platform_users 
  WHERE auth_user_id = auth.uid()
));

CREATE POLICY "System can manage all collection logs" 
ON public.policy_collection_logs 
FOR ALL 
USING (true);

-- Políticas RLS para policy_collection_settings
CREATE POLICY "Users can manage collection settings for their firm" 
ON public.policy_collection_settings 
FOR ALL 
USING (law_firm_id IN (
  SELECT law_firm_id FROM platform_users 
  WHERE auth_user_id = auth.uid()
));

-- Índices para performance
CREATE INDEX idx_policy_rules_effective_date ON policy_rules(effective_date);
CREATE INDEX idx_policy_rules_source_type ON policy_rules(source_type);
CREATE INDEX idx_policy_rules_law_firm ON policy_rules(law_firm_id);
CREATE INDEX idx_policy_rules_status ON policy_rules(status);
CREATE INDEX idx_policy_collection_logs_started_at ON policy_collection_logs(started_at);
CREATE INDEX idx_policy_collection_logs_status ON policy_collection_logs(status);

-- Triggers para updated_at
CREATE TRIGGER update_policy_rules_updated_at
BEFORE UPDATE ON public.policy_rules
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_policy_collection_settings_updated_at
BEFORE UPDATE ON public.policy_collection_settings
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Inserir configurações padrão do USCIS
INSERT INTO public.policy_collection_settings (
  law_firm_id, 
  source_name, 
  source_url, 
  collection_frequency,
  filters
) VALUES (
  '550e8400-e29b-41d4-a716-446655440001',
  'USCIS Policy Manual',
  'https://www.uscis.gov/policy-manual',
  'daily',
  '{"categories": ["family", "employment", "naturalization"], "formats": ["html", "pdf"]}'
),
(
  '550e8400-e29b-41d4-a716-446655440001',
  'USCIS News Updates',
  'https://www.uscis.gov/news',
  'daily',
  '{"keywords": ["policy", "update", "change", "new"], "date_range": "30"}'
);