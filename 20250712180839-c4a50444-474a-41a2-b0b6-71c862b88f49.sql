-- Add data retention policies to law firms
ALTER TABLE public.law_firms ADD COLUMN data_retention_days INTEGER DEFAULT 90;
ALTER TABLE public.law_firms ADD COLUMN auto_cleanup_enabled BOOLEAN DEFAULT true;

-- Add completion tracking to cases
ALTER TABLE public.cases ADD COLUMN data_cleanup_status TEXT DEFAULT 'active' CHECK (data_cleanup_status IN ('active', 'scheduled_for_cleanup', 'cleaned'));
ALTER TABLE public.cases ADD COLUMN cleanup_scheduled_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.cases ADD COLUMN cleanup_completed_at TIMESTAMP WITH TIME ZONE;

-- Create data cleanup logs table for auditing
CREATE TABLE public.data_cleanup_logs (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  case_id UUID REFERENCES public.cases(id) ON DELETE SET NULL,
  action TEXT NOT NULL CHECK (action IN ('scheduled', 'completed', 'failed')),
  data_types TEXT[] NOT NULL, -- ['clients', 'documents', 'activities', etc]
  reason TEXT,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_by UUID -- References platform user who triggered the action
);

-- Create data retention settings table
CREATE TABLE public.data_retention_settings (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  law_firm_id UUID NOT NULL REFERENCES public.law_firms(id) ON DELETE CASCADE,
  data_type TEXT NOT NULL CHECK (data_type IN ('clients', 'case_documents', 'case_activities', 'ai_interactions', 'all')),
  retention_days INTEGER NOT NULL,
  auto_cleanup BOOLEAN NOT NULL DEFAULT true,
  notify_before_cleanup BOOLEAN NOT NULL DEFAULT true,
  notification_days INTEGER DEFAULT 7, -- Notify X days before cleanup
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  
  UNIQUE(law_firm_id, data_type)
);

-- Enable RLS on new tables
ALTER TABLE public.data_cleanup_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_retention_settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for data_cleanup_logs
CREATE POLICY "Users can view their firm's cleanup logs" 
ON public.data_cleanup_logs 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage their firm's cleanup logs" 
ON public.data_cleanup_logs 
FOR ALL 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- RLS Policies for data_retention_settings
CREATE POLICY "Users can view their firm's retention settings" 
ON public.data_retention_settings 
FOR SELECT 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
);

CREATE POLICY "Admins can manage their firm's retention settings" 
ON public.data_retention_settings 
FOR ALL 
USING (
  law_firm_id IN (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- Add triggers for updated_at
CREATE TRIGGER update_data_retention_settings_updated_at
  BEFORE UPDATE ON public.data_retention_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Function to schedule case cleanup when status changes to completed
CREATE OR REPLACE FUNCTION public.schedule_case_cleanup()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  firm_retention_days INTEGER;
  cleanup_date TIMESTAMP WITH TIME ZONE;
BEGIN
  -- Only trigger when status changes to 'concluido'
  IF NEW.status = 'concluido' AND (OLD.status IS NULL OR OLD.status != 'concluido') THEN
    
    -- Get firm's data retention policy
    SELECT data_retention_days INTO firm_retention_days
    FROM public.law_firms 
    WHERE id IN (
      SELECT law_firm_id FROM public.platform_users 
      WHERE auth_user_id = auth.uid()
      LIMIT 1
    );
    
    -- Default to 90 days if not set
    IF firm_retention_days IS NULL THEN
      firm_retention_days := 90;
    END IF;
    
    -- Calculate cleanup date
    cleanup_date := NEW.data_conclusao + INTERVAL '1 day' * firm_retention_days;
    
    -- Update case with cleanup schedule
    NEW.data_cleanup_status := 'scheduled_for_cleanup';
    NEW.cleanup_scheduled_at := cleanup_date;
    
    -- Log the scheduling
    INSERT INTO public.data_cleanup_logs (
      law_firm_id,
      case_id,
      action,
      data_types,
      reason,
      metadata
    ) VALUES (
      (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = auth.uid() LIMIT 1),
      NEW.id,
      'scheduled',
      ARRAY['clients', 'case_documents', 'case_activities'],
      'Case completed - automatic cleanup scheduled',
      jsonb_build_object(
        'scheduled_for', cleanup_date,
        'retention_days', firm_retention_days,
        'case_completion_date', NEW.data_conclusao
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for automatic cleanup scheduling
CREATE TRIGGER trigger_schedule_case_cleanup
  BEFORE UPDATE ON public.cases
  FOR EACH ROW
  EXECUTE FUNCTION public.schedule_case_cleanup();

-- Function to get cases ready for cleanup
CREATE OR REPLACE FUNCTION public.get_cases_ready_for_cleanup()
RETURNS TABLE (
  case_id UUID,
  law_firm_id UUID,
  case_title TEXT,
  completion_date DATE,
  scheduled_cleanup_date TIMESTAMP WITH TIME ZONE
)
LANGUAGE sql
SECURITY DEFINER SET search_path = ''
AS $$
  SELECT 
    c.id,
    pu.law_firm_id,
    c.titulo,
    c.data_conclusao,
    c.cleanup_scheduled_at
  FROM public.cases c
  JOIN public.platform_users pu ON pu.auth_user_id = auth.uid()
  WHERE c.data_cleanup_status = 'scheduled_for_cleanup'
    AND c.cleanup_scheduled_at <= now()
    AND EXISTS (
      SELECT 1 FROM public.platform_users 
      WHERE auth_user_id = auth.uid() 
      AND law_firm_id = pu.law_firm_id
    );
$$;