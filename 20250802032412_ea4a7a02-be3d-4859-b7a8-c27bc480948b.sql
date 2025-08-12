-- Create notification settings table
CREATE TABLE public.notification_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  email_enabled BOOLEAN NOT NULL DEFAULT true,
  slack_enabled BOOLEAN NOT NULL DEFAULT false,
  email_recipients TEXT[] NOT NULL DEFAULT '{}',
  slack_webhook_url TEXT,
  notification_frequency TEXT NOT NULL DEFAULT 'immediate',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create monitoring jobs table
CREATE TABLE public.monitoring_jobs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  job_type TEXT NOT NULL DEFAULT 'policy_check',
  status TEXT NOT NULL DEFAULT 'pending',
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  results JSONB,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Create policy change notifications table
CREATE TABLE public.policy_change_notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL,
  notification_type TEXT NOT NULL DEFAULT 'policy_change',
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  sent_at TIMESTAMP WITH TIME ZONE,
  delivery_status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.monitoring_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.policy_change_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notification_settings
CREATE POLICY "Users can manage notification settings for their firm" 
ON public.notification_settings 
FOR ALL 
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id 
  FROM platform_users 
  WHERE platform_users.auth_user_id = auth.uid()
));

-- RLS Policies for monitoring_jobs
CREATE POLICY "System can manage all monitoring jobs" 
ON public.monitoring_jobs 
FOR ALL 
USING (true);

CREATE POLICY "Users can view monitoring jobs" 
ON public.monitoring_jobs 
FOR SELECT 
USING (true);

-- RLS Policies for policy_change_notifications
CREATE POLICY "System can manage all notifications" 
ON public.policy_change_notifications 
FOR ALL 
USING (true);

CREATE POLICY "Users can view notifications for their firm" 
ON public.policy_change_notifications 
FOR SELECT 
USING (law_firm_id IN (
  SELECT platform_users.law_firm_id 
  FROM platform_users 
  WHERE platform_users.auth_user_id = auth.uid()
));

-- Add updated_at triggers
CREATE TRIGGER update_notification_settings_updated_at
  BEFORE UPDATE ON public.notification_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Add indexes for performance
CREATE INDEX idx_notification_settings_law_firm_id ON public.notification_settings(law_firm_id);
CREATE INDEX idx_monitoring_jobs_status ON public.monitoring_jobs(status);
CREATE INDEX idx_monitoring_jobs_created_at ON public.monitoring_jobs(created_at);
CREATE INDEX idx_policy_change_notifications_law_firm_id ON public.policy_change_notifications(law_firm_id);
CREATE INDEX idx_policy_change_notifications_delivery_status ON public.policy_change_notifications(delivery_status);

-- Insert default notification settings for existing firms
INSERT INTO public.notification_settings (law_firm_id, email_enabled, slack_enabled)
SELECT DISTINCT id, true, false
FROM public.law_firms
ON CONFLICT DO NOTHING;