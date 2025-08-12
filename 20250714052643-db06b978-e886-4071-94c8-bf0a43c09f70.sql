-- Create API endpoints table
CREATE TABLE public.api_endpoints (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  method TEXT NOT NULL DEFAULT 'GET',
  headers JSONB DEFAULT '{}',
  rate_limit INTEGER DEFAULT 100,
  timeout INTEGER DEFAULT 30000,
  retries INTEGER DEFAULT 3,
  active BOOLEAN DEFAULT true,
  last_status TEXT DEFAULT 'pending',
  response_time INTEGER DEFAULT 0,
  success_rate NUMERIC DEFAULT 100.0,
  last_tested_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create webhook configs table
CREATE TABLE public.webhook_configs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  name TEXT NOT NULL,
  url TEXT NOT NULL,
  events TEXT[] DEFAULT '{}',
  active BOOLEAN DEFAULT true,
  secret TEXT,
  retries INTEGER DEFAULT 3,
  last_triggered_at TIMESTAMP WITH TIME ZONE,
  delivery_status TEXT DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create API logs table
CREATE TABLE public.api_endpoint_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  endpoint_id UUID NOT NULL,
  request_data JSONB,
  response_data JSONB,
  status_code INTEGER,
  response_time INTEGER,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create integration settings table
CREATE TABLE public.integration_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  provider TEXT NOT NULL,
  config JSONB NOT NULL DEFAULT '{}',
  credentials JSONB,
  active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.api_endpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_endpoint_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integration_settings ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for api_endpoints
CREATE POLICY "Users can manage API endpoints in their firm"
ON public.api_endpoints
FOR ALL
USING (law_firm_id IN (
  SELECT law_firm_id FROM public.platform_users 
  WHERE auth_user_id = auth.uid()
));

-- Create RLS policies for webhook_configs  
CREATE POLICY "Users can manage webhook configs in their firm"
ON public.webhook_configs
FOR ALL
USING (law_firm_id IN (
  SELECT law_firm_id FROM public.platform_users 
  WHERE auth_user_id = auth.uid()
));

-- Create RLS policies for api_endpoint_logs
CREATE POLICY "Users can view API logs from their firm endpoints"
ON public.api_endpoint_logs
FOR SELECT
USING (endpoint_id IN (
  SELECT id FROM public.api_endpoints ae
  WHERE ae.law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
));

-- Create RLS policies for integration_settings
CREATE POLICY "Users can manage integration settings in their firm"
ON public.integration_settings
FOR ALL
USING (law_firm_id IN (
  SELECT law_firm_id FROM public.platform_users 
  WHERE auth_user_id = auth.uid()
));

-- Add foreign key constraints
ALTER TABLE public.api_endpoints 
ADD CONSTRAINT api_endpoints_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

ALTER TABLE public.webhook_configs 
ADD CONSTRAINT webhook_configs_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

ALTER TABLE public.api_endpoint_logs 
ADD CONSTRAINT api_endpoint_logs_endpoint_id_fkey 
FOREIGN KEY (endpoint_id) REFERENCES public.api_endpoints(id) ON DELETE CASCADE;

ALTER TABLE public.integration_settings 
ADD CONSTRAINT integration_settings_law_firm_id_fkey 
FOREIGN KEY (law_firm_id) REFERENCES public.law_firms(id);

-- Create triggers for updated_at
CREATE TRIGGER update_api_endpoints_updated_at
BEFORE UPDATE ON public.api_endpoints
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_webhook_configs_updated_at
BEFORE UPDATE ON public.webhook_configs
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_integration_settings_updated_at
BEFORE UPDATE ON public.integration_settings
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();