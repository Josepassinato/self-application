-- Tabelas para métricas de uso e SLA

-- Tabela de métricas de uso
CREATE TABLE IF NOT EXISTS public.usage_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  metric_type text NOT NULL, -- 'documents_generated', 'ai_analysis', 'api_calls', etc.
  metric_value integer NOT NULL DEFAULT 0,
  period_start timestamp with time zone NOT NULL,
  period_end timestamp with time zone NOT NULL,
  metadata jsonb DEFAULT '{}',
  created_at timestamp with time zone NOT NULL DEFAULT now()
);

-- Tabela de alertas de uso
CREATE TABLE IF NOT EXISTS public.usage_alerts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  alert_type text NOT NULL, -- 'warning_80', 'warning_90', 'limit_reached'
  metric_type text NOT NULL,
  current_usage integer NOT NULL,
  limit_value integer NOT NULL,
  percentage_used decimal(5,2) NOT NULL,
  triggered_at timestamp with time zone NOT NULL DEFAULT now(),
  acknowledged boolean DEFAULT false,
  acknowledged_at timestamp with time zone,
  acknowledged_by uuid
);

-- Tabela de SLA metrics
CREATE TABLE IF NOT EXISTS public.sla_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id uuid NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  service_name text NOT NULL, -- 'api', 'ai_analysis', 'document_generation'
  response_time_ms integer,
  success boolean NOT NULL,
  error_message text,
  endpoint text,
  user_id uuid,
  measured_at timestamp with time zone NOT NULL DEFAULT now()
);

-- RLS policies
ALTER TABLE public.usage_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sla_metrics ENABLE ROW LEVEL SECURITY;

-- Políticas para usage_metrics
CREATE POLICY "Users can view metrics from their firm" ON public.usage_metrics
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage metrics" ON public.usage_metrics
FOR ALL USING (true);

-- Políticas para usage_alerts  
CREATE POLICY "Users can view alerts from their firm" ON public.usage_alerts
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage alerts" ON public.usage_alerts
FOR ALL USING (true);

-- Políticas para sla_metrics
CREATE POLICY "Users can view SLA metrics from their firm" ON public.sla_metrics
FOR SELECT USING (
  law_firm_id IN (
    SELECT platform_users.law_firm_id
    FROM platform_users
    WHERE platform_users.auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can create SLA metrics" ON public.sla_metrics
FOR INSERT WITH CHECK (true);