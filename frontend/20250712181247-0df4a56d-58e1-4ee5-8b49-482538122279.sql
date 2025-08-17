-- Enable pg_cron extension for scheduled tasks
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Enable pg_net extension for HTTP requests
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Create notifications table for cleanup warnings
CREATE TABLE public.cleanup_notifications (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  case_id UUID REFERENCES public.cases(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL CHECK (notification_type IN ('cleanup_warning', 'cleanup_completed', 'cleanup_failed')),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  metadata JSONB,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  scheduled_for TIMESTAMP WITH TIME ZONE -- For future notifications
);

-- Enable RLS on notifications
ALTER TABLE public.cleanup_notifications ENABLE ROW LEVEL SECURITY;

-- RLS Policies for notifications
CREATE POLICY "Users can view their firm's notifications" 
ON public.cleanup_notifications 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "System can manage all notifications" 
ON public.cleanup_notifications 
FOR ALL 
USING (true);

-- Create index for better performance
CREATE INDEX idx_cleanup_notifications_firm_created ON public.cleanup_notifications(law_firm_id, created_at DESC);
CREATE INDEX idx_cleanup_notifications_scheduled ON public.cleanup_notifications(scheduled_for) WHERE scheduled_for IS NOT NULL;

-- Function to create cleanup warning notifications
CREATE OR REPLACE FUNCTION public.create_cleanup_warnings()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  notification_count INTEGER := 0;
  case_record RECORD;
  firm_record RECORD;
  warning_date TIMESTAMP WITH TIME ZONE;
  existing_notification RECORD;
BEGIN
  -- Get all cases that need cleanup warnings
  FOR case_record IN
    SELECT 
      c.id as case_id,
      c.titulo as case_title,
      c.cleanup_scheduled_at,
      pu.law_firm_id,
      lf.name as firm_name
    FROM public.cases c
    JOIN public.platform_users pu ON true -- We need to get all firms
    JOIN public.law_firms lf ON lf.id = pu.law_firm_id
    WHERE c.data_cleanup_status = 'scheduled_for_cleanup'
      AND c.cleanup_scheduled_at IS NOT NULL
      AND c.cleanup_scheduled_at > now()
  LOOP
    -- Get firm's notification settings
    SELECT rs.notification_days INTO warning_date
    FROM public.data_retention_settings rs
    WHERE rs.law_firm_id = case_record.law_firm_id
      AND rs.data_type = 'clients'
      AND rs.notify_before_cleanup = true
    LIMIT 1;
    
    -- Default to 7 days if not configured
    IF warning_date IS NULL THEN
      warning_date := 7;
    END IF;
    
    -- Calculate when to send warning
    warning_date := case_record.cleanup_scheduled_at - INTERVAL '1 day' * warning_date;
    
    -- Only create notification if warning date has passed and cleanup hasn't happened yet
    IF warning_date <= now() AND case_record.cleanup_scheduled_at > now() THEN
      -- Check if notification already exists
      SELECT id INTO existing_notification
      FROM public.cleanup_notifications
      WHERE case_id = case_record.case_id
        AND notification_type = 'cleanup_warning'
        AND law_firm_id = case_record.law_firm_id;
      
      -- Create notification if it doesn't exist
      IF existing_notification IS NULL THEN
        INSERT INTO public.cleanup_notifications (
          law_firm_id,
          case_id,
          notification_type,
          title,
          message,
          metadata
        ) VALUES (
          case_record.law_firm_id,
          case_record.case_id,
          'cleanup_warning',
          'Limpeza de Dados Agendada',
          format('O caso "%s" terá seus dados removidos em %s. Certifique-se de que os dados foram sincronizados com seu sistema.',
                 case_record.case_title,
                 to_char(case_record.cleanup_scheduled_at, 'DD/MM/YYYY HH24:MI')),
          jsonb_build_object(
            'case_title', case_record.case_title,
            'cleanup_date', case_record.cleanup_scheduled_at,
            'firm_name', case_record.firm_name,
            'warning_generated_at', now()
          )
        );
        
        notification_count := notification_count + 1;
      END IF;
    END IF;
  END LOOP;
  
  RETURN notification_count;
END;
$$;

-- Function to get unread notifications count
CREATE OR REPLACE FUNCTION public.get_unread_notifications_count(user_firm_id UUID)
RETURNS INTEGER
LANGUAGE sql
SECURITY DEFINER SET search_path = ''
AS $$
  SELECT COUNT(*)::INTEGER
  FROM public.cleanup_notifications
  WHERE law_firm_id = user_firm_id
    AND is_read = false;
$$;

-- Schedule automatic data cleanup to run every hour
SELECT cron.schedule(
  'automatic-data-cleanup',
  '0 * * * *', -- Every hour at minute 0
  $$
  SELECT net.http_post(
    url := 'https://apoeceltgnvohsbxfopb.supabase.co/functions/v1/data-cleanup',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFwb2VjZWx0Z252b2hzYnhmb3BiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNDA2MDQsImV4cCI6MjA2NzkxNjYwNH0.IzKP2-n-EGVkfZ-wXQdAmtK36nryqZc8RFEY0qZL6qM"}'::jsonb,
    body := '{"scheduled": true}'::jsonb
  );
  $$
);

-- Schedule cleanup warning notifications to run daily at 9 AM
SELECT cron.schedule(
  'cleanup-warnings',
  '0 9 * * *', -- Daily at 9 AM
  $$
  SELECT public.create_cleanup_warnings();
  $$
);