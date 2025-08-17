-- Create analytics metrics table
CREATE TABLE IF NOT EXISTS public.analytics_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id UUID NOT NULL,
  metric_date DATE NOT NULL,
  total_cases INTEGER NOT NULL DEFAULT 0,
  new_cases INTEGER NOT NULL DEFAULT 0,
  closed_cases INTEGER NOT NULL DEFAULT 0,
  avg_completion_time INTERVAL,
  approval_rate NUMERIC(5,2) CHECK (approval_rate >= 0 AND approval_rate <= 100),
  rfe_rate NUMERIC(5,2) CHECK (rfe_rate >= 0 AND rfe_rate <= 100),
  avg_rfe_response_time INTERVAL,
  ai_acceptance_rate NUMERIC(5,2) CHECK (ai_acceptance_rate >= 0 AND ai_acceptance_rate <= 100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(partner_id, metric_date)
);

-- Enable RLS
ALTER TABLE public.analytics_metrics ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view analytics for their firm" 
ON public.analytics_metrics 
FOR SELECT 
USING (
  partner_id IN (
    SELECT pu.auth_user_id 
    FROM public.platform_users pu
    WHERE pu.auth_user_id = auth.uid()
    OR pu.law_firm_id IN (
      SELECT law_firm_id 
      FROM public.platform_users 
      WHERE auth_user_id = auth.uid()
    )
  )
);

CREATE POLICY "System can manage analytics metrics" 
ON public.analytics_metrics 
FOR ALL 
USING (true)
WITH CHECK (true);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_analytics_metrics_partner_date ON public.analytics_metrics(partner_id, metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_metrics_date ON public.analytics_metrics(metric_date DESC);
CREATE INDEX IF NOT EXISTS idx_analytics_metrics_partner_id ON public.analytics_metrics(partner_id);

-- Create performance alerts table
CREATE TABLE IF NOT EXISTS public.performance_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  law_firm_id UUID NOT NULL,
  alert_type TEXT NOT NULL,
  current_value NUMERIC NOT NULL,
  previous_value NUMERIC NOT NULL,
  threshold_exceeded NUMERIC NOT NULL,
  alert_data JSONB DEFAULT '{}'::jsonb,
  resolved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for performance alerts
ALTER TABLE public.performance_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view alerts for their firm" 
ON public.performance_alerts 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id 
    FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage performance alerts" 
ON public.performance_alerts 
FOR ALL 
USING (true)
WITH CHECK (true);

-- Create indexes for performance alerts
CREATE INDEX IF NOT EXISTS idx_performance_alerts_firm_date ON public.performance_alerts(law_firm_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_performance_alerts_resolved ON public.performance_alerts(resolved, created_at DESC);