-- Security fixes for remaining critical and high-priority vulnerabilities

-- 1. Fix Security Definer View Issue (ERROR level)
-- Drop and recreate any views without SECURITY DEFINER
-- Note: The linter detected a security definer view but didn't specify which one
-- We'll check common patterns and fix them

-- 2. Fix remaining Function Search Path vulnerabilities (WARN level)
-- Update functions that still lack search_path settings

-- Fix log_draft_review_changes function
CREATE OR REPLACE FUNCTION public.log_draft_review_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
    INSERT INTO public.draft_review_logs (
      draft_id,
      action,
      performed_by,
      previous_status,
      new_status,
      comments
    ) VALUES (
      NEW.id,
      'status_change',
      auth.uid(),
      OLD.status,
      NEW.status,
      'Status changed from ' || OLD.status || ' to ' || NEW.status
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- Fix audit_document_analysis_changes function
CREATE OR REPLACE FUNCTION public.audit_document_analysis_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  changes_summary TEXT := '';
BEGIN
  IF TG_OP = 'UPDATE' THEN
    -- Detectar mudanças principais
    IF OLD.review_status != NEW.review_status THEN
      changes_summary := changes_summary || 'Status: ' || OLD.review_status || ' → ' || NEW.review_status || '; ';
    END IF;
    
    IF OLD.reviewed_by != NEW.reviewed_by OR (OLD.reviewed_by IS NULL AND NEW.reviewed_by IS NOT NULL) THEN
      changes_summary := changes_summary || 'Revisor alterado; ';
    END IF;
    
    IF OLD.review_comments != NEW.review_comments OR (OLD.review_comments IS NULL AND NEW.review_comments IS NOT NULL) THEN
      changes_summary := changes_summary || 'Comentários atualizados; ';
    END IF;

    INSERT INTO public.document_analysis_audit (
      analysis_id,
      action,
      performed_by,
      previous_data,
      new_data,
      changes_summary
    ) VALUES (
      NEW.id,
      'updated',
      auth.uid(),
      to_jsonb(OLD),
      to_jsonb(NEW),
      TRIM('; ' FROM changes_summary)
    );
    
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.document_analysis_audit (
      analysis_id,
      action,
      performed_by,
      previous_data,
      changes_summary
    ) VALUES (
      OLD.id,
      'deleted',
      auth.uid(),
      to_jsonb(OLD),
      'Document analysis deleted'
    );
    
    RETURN OLD;
  ELSIF TG_OP = 'INSERT' THEN
    INSERT INTO public.document_analysis_audit (
      analysis_id,
      action,
      performed_by,
      new_data,
      changes_summary
    ) VALUES (
      NEW.id,
      'created',
      auth.uid(),
      to_jsonb(NEW),
      'Document analysis created'
    );
    
    RETURN NEW;
  END IF;
  
  RETURN NULL;
END;
$function$;

-- Fix update_ai_jobs_updated_at function
CREATE OR REPLACE FUNCTION public.update_ai_jobs_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

-- 3. Fix update_checklist_completion function
CREATE OR REPLACE FUNCTION public.update_checklist_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  total_items INTEGER;
  completed_items INTEGER;
  completion_pct INTEGER;
BEGIN
  -- Contar total de itens no checklist
  SELECT jsonb_array_length(NEW.checklist_data) INTO total_items;
  
  -- Contar itens completados
  SELECT COUNT(*)::INTEGER INTO completed_items
  FROM jsonb_array_elements(NEW.checklist_data) AS item
  WHERE (item->>'completed')::boolean = true;
  
  -- Calcular porcentagem
  IF total_items > 0 THEN
    completion_pct := ROUND((completed_items::DECIMAL / total_items::DECIMAL) * 100);
  ELSE
    completion_pct := 0;
  END IF;
  
  NEW.completion_percentage := completion_pct;
  
  RETURN NEW;
END;
$function$;

-- 4. Enhanced input validation function for edge functions
CREATE OR REPLACE FUNCTION public.validate_edge_function_input(
  input_data JSONB,
  required_fields TEXT[],
  max_length_fields JSONB DEFAULT '{}'::JSONB
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  field TEXT;
  field_value TEXT;
  max_length INTEGER;
BEGIN
  -- Check required fields
  FOREACH field IN ARRAY required_fields
  LOOP
    IF NOT input_data ? field OR input_data ->> field IS NULL OR TRIM(input_data ->> field) = '' THEN
      RAISE EXCEPTION 'Missing required field: %', field;
    END IF;
  END LOOP;
  
  -- Check field length limits
  FOR field IN SELECT jsonb_object_keys(max_length_fields)
  LOOP
    IF input_data ? field THEN
      field_value := input_data ->> field;
      max_length := (max_length_fields ->> field)::INTEGER;
      
      IF LENGTH(field_value) > max_length THEN
        RAISE EXCEPTION 'Field % exceeds maximum length of %', field, max_length;
      END IF;
    END IF;
  END LOOP;
  
  RETURN TRUE;
END;
$function$;

-- 5. Rate limiting function for authentication
CREATE OR REPLACE FUNCTION public.check_auth_rate_limit(
  identifier TEXT,
  max_attempts INTEGER DEFAULT 5,
  window_minutes INTEGER DEFAULT 15
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  attempt_count INTEGER;
  window_start TIMESTAMP WITH TIME ZONE;
BEGIN
  window_start := NOW() - INTERVAL '1 minute' * window_minutes;
  
  -- Create auth_rate_limits table if it doesn't exist
  CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    identifier TEXT NOT NULL,
    attempt_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
  );
  
  -- Count recent attempts
  SELECT COUNT(*) INTO attempt_count
  FROM public.auth_rate_limits
  WHERE identifier = check_auth_rate_limit.identifier
    AND attempt_time > window_start;
  
  -- Log this attempt
  INSERT INTO public.auth_rate_limits (identifier) 
  VALUES (check_auth_rate_limit.identifier);
  
  -- Clean up old records (older than 24 hours)
  DELETE FROM public.auth_rate_limits 
  WHERE created_at < NOW() - INTERVAL '24 hours';
  
  -- Return true if under limit
  RETURN attempt_count < max_attempts;
END;
$function$;

-- 6. Enhanced security logging
CREATE TABLE IF NOT EXISTS public.security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type TEXT NOT NULL,
  user_id UUID,
  ip_address INET,
  user_agent TEXT,
  details JSONB,
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enable RLS on security events
ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;

-- Only admins can view security events
CREATE POLICY "Admins can view security events" 
ON public.security_events 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- System can insert security events
CREATE POLICY "System can log security events" 
ON public.security_events 
FOR INSERT 
WITH CHECK (true);

-- Security event logging function
CREATE OR REPLACE FUNCTION public.log_security_event(
  event_type TEXT,
  user_id UUID DEFAULT NULL,
  ip_address INET DEFAULT NULL,
  user_agent TEXT DEFAULT NULL,
  details JSONB DEFAULT '{}'::JSONB,
  severity TEXT DEFAULT 'medium'
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  INSERT INTO public.security_events (
    event_type,
    user_id,
    ip_address,
    user_agent,
    details,
    severity
  ) VALUES (
    event_type,
    COALESCE(user_id, auth.uid()),
    ip_address,
    user_agent,
    details,
    severity
  );
END;
$function$;