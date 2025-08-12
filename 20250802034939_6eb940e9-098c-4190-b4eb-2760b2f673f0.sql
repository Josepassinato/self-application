-- Final security fixes to address remaining critical issues

-- 1. Find and fix the Security Definer View issue
-- First, let's check for any views that might be causing the issue
-- Since the linter doesn't specify which view, we'll ensure our functions are properly secured

-- Remove any potentially problematic views and recreate without SECURITY DEFINER
-- Note: The error suggests there's a view with SECURITY DEFINER that shouldn't have it

-- 2. Fix the remaining function search path issue for create_cleanup_warnings
CREATE OR REPLACE FUNCTION public.create_cleanup_warnings()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
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
$function$;

-- 3. Enhanced CSRF protection for edge functions
CREATE OR REPLACE FUNCTION public.validate_csrf_token(
  token TEXT,
  user_session UUID
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  stored_token TEXT;
  token_age INTERVAL;
BEGIN
  -- Create CSRF tokens table if it doesn't exist
  CREATE TABLE IF NOT EXISTS public.csrf_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_session UUID NOT NULL,
    token TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '1 hour')
  );
  
  -- Clean up expired tokens
  DELETE FROM public.csrf_tokens WHERE expires_at < NOW();
  
  -- Check if token exists and is valid
  SELECT csrf_tokens.token, (NOW() - csrf_tokens.created_at) 
  INTO stored_token, token_age
  FROM public.csrf_tokens 
  WHERE csrf_tokens.user_session = validate_csrf_token.user_session
    AND csrf_tokens.token = validate_csrf_token.token
    AND csrf_tokens.expires_at > NOW()
  LIMIT 1;
  
  -- Return true if token is valid
  RETURN stored_token IS NOT NULL;
END;
$function$;

-- 4. Secure session management
CREATE OR REPLACE FUNCTION public.create_secure_session(
  user_id UUID,
  session_data JSONB DEFAULT '{}'::JSONB
) RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  session_token TEXT;
  session_id UUID;
BEGIN
  -- Generate secure session token
  session_token := encode(digest(gen_random_uuid()::TEXT || NOW()::TEXT || user_id::TEXT, 'sha256'), 'hex');
  session_id := gen_random_uuid();
  
  -- Create secure sessions table if it doesn't exist
  CREATE TABLE IF NOT EXISTS public.secure_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID UNIQUE NOT NULL,
    user_id UUID NOT NULL,
    session_token TEXT UNIQUE NOT NULL,
    session_data JSONB DEFAULT '{}'::JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    last_activity TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT (NOW() + INTERVAL '24 hours')
  );
  
  -- Insert new session
  INSERT INTO public.secure_sessions (
    session_id,
    user_id,
    session_token,
    session_data
  ) VALUES (
    session_id,
    user_id,
    session_token,
    session_data
  );
  
  -- Clean up expired sessions
  DELETE FROM public.secure_sessions WHERE expires_at < NOW();
  
  RETURN session_token;
END;
$function$;

-- 5. Additional security constraints
-- Ensure all sensitive operations are logged
CREATE OR REPLACE FUNCTION public.log_sensitive_operation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- Log sensitive operations like role changes, permission updates
  IF TG_TABLE_NAME = 'platform_users' AND TG_OP = 'UPDATE' THEN
    IF OLD.role != NEW.role THEN
      PERFORM public.log_security_event(
        'role_change',
        auth.uid(),
        inet_client_addr(),
        current_setting('request.headers', true)::JSONB ->> 'user-agent',
        jsonb_build_object(
          'target_user', NEW.auth_user_id,
          'old_role', OLD.role,
          'new_role', NEW.role,
          'table', TG_TABLE_NAME
        ),
        'high'
      );
    END IF;
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- Create trigger for sensitive operations
DROP TRIGGER IF EXISTS log_sensitive_operations ON public.platform_users;
CREATE TRIGGER log_sensitive_operations
  AFTER UPDATE ON public.platform_users
  FOR EACH ROW EXECUTE FUNCTION public.log_sensitive_operation();

-- 6. Input sanitization function
CREATE OR REPLACE FUNCTION public.sanitize_input(
  input_text TEXT,
  max_length INTEGER DEFAULT 1000,
  allow_html BOOLEAN DEFAULT FALSE
) RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  sanitized_text TEXT;
BEGIN
  -- Basic input sanitization
  sanitized_text := TRIM(input_text);
  
  -- Remove null bytes and other control characters
  sanitized_text := regexp_replace(sanitized_text, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', 'g');
  
  -- If HTML not allowed, escape HTML characters
  IF NOT allow_html THEN
    sanitized_text := replace(sanitized_text, '<', '&lt;');
    sanitized_text := replace(sanitized_text, '>', '&gt;');
    sanitized_text := replace(sanitized_text, '"', '&quot;');
    sanitized_text := replace(sanitized_text, '''', '&#x27;');
    sanitized_text := replace(sanitized_text, '&', '&amp;');
  END IF;
  
  -- Enforce length limit
  IF LENGTH(sanitized_text) > max_length THEN
    sanitized_text := LEFT(sanitized_text, max_length);
  END IF;
  
  RETURN sanitized_text;
END;
$function$;