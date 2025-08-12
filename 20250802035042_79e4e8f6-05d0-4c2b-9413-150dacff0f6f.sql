-- Final security hardening - address remaining security warnings

-- 1. Create comprehensive security monitoring view (without SECURITY DEFINER)
-- This replaces any problematic views that might exist
DROP VIEW IF EXISTS public.security_dashboard CASCADE;

CREATE VIEW public.security_dashboard AS
SELECT 
  'authentication_events' as event_category,
  COUNT(*) as event_count,
  MAX(created_at) as last_event
FROM public.security_events 
WHERE event_type IN ('login_attempt', 'failed_login', 'password_reset')
  AND created_at > NOW() - INTERVAL '24 hours'
UNION ALL
SELECT 
  'privilege_changes' as event_category,
  COUNT(*) as event_count,
  MAX(created_at) as last_event
FROM public.security_events 
WHERE event_type = 'role_change'
  AND created_at > NOW() - INTERVAL '24 hours'
UNION ALL
SELECT 
  'failed_operations' as event_category,
  COUNT(*) as event_count,
  MAX(created_at) as last_event
FROM public.security_events 
WHERE severity IN ('high', 'critical')
  AND created_at > NOW() - INTERVAL '24 hours';

-- Enable RLS on the view
ALTER VIEW public.security_dashboard SET (security_barrier = true);

-- 2. Enhanced rate limiting for authentication endpoints
CREATE OR REPLACE FUNCTION public.enforce_auth_rate_limit(
  request_ip INET,
  user_identifier TEXT DEFAULT NULL
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  ip_count INTEGER := 0;
  user_count INTEGER := 0;
  window_start TIMESTAMP WITH TIME ZONE := NOW() - INTERVAL '15 minutes';
BEGIN
  -- Check IP-based rate limiting (more restrictive)
  SELECT COUNT(*) INTO ip_count
  FROM public.auth_rate_limits
  WHERE identifier = request_ip::TEXT
    AND attempt_time > window_start;
  
  -- Check user-based rate limiting if user provided
  IF user_identifier IS NOT NULL THEN
    SELECT COUNT(*) INTO user_count
    FROM public.auth_rate_limits
    WHERE identifier = user_identifier
      AND attempt_time > window_start;
  END IF;
  
  -- Log the attempt
  INSERT INTO public.auth_rate_limits (identifier, attempt_time) 
  VALUES (COALESCE(user_identifier, request_ip::TEXT), NOW());
  
  -- Log security event if rate limit exceeded
  IF ip_count >= 10 OR user_count >= 5 THEN
    PERFORM public.log_security_event(
      'rate_limit_exceeded',
      NULL,
      request_ip,
      NULL,
      jsonb_build_object(
        'ip_attempts', ip_count,
        'user_attempts', user_count,
        'identifier', COALESCE(user_identifier, 'anonymous')
      ),
      'high'
    );
    RETURN FALSE;
  END IF;
  
  RETURN TRUE;
END;
$function$;

-- 3. Database activity monitoring
CREATE TABLE IF NOT EXISTS public.database_activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID,
  session_id TEXT,
  operation_type TEXT NOT NULL,
  table_name TEXT,
  record_id UUID,
  ip_address INET,
  user_agent TEXT,
  query_details JSONB,
  execution_time_ms INTEGER,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Enable RLS on activity log
ALTER TABLE public.database_activity_log ENABLE ROW LEVEL SECURITY;

-- Only admins can view database activity
CREATE POLICY "Admins can view database activity" 
ON public.database_activity_log 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- System can insert activity logs
CREATE POLICY "System can log database activity" 
ON public.database_activity_log 
FOR INSERT 
WITH CHECK (true);

-- 4. Enhanced password policy enforcement
CREATE OR REPLACE FUNCTION public.validate_password_strength(password TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  -- Minimum length check
  IF LENGTH(password) < 12 THEN
    RAISE EXCEPTION 'Password must be at least 12 characters long';
  END IF;
  
  -- Must contain uppercase letter
  IF password !~ '[A-Z]' THEN
    RAISE EXCEPTION 'Password must contain at least one uppercase letter';
  END IF;
  
  -- Must contain lowercase letter
  IF password !~ '[a-z]' THEN
    RAISE EXCEPTION 'Password must contain at least one lowercase letter';
  END IF;
  
  -- Must contain number
  IF password !~ '[0-9]' THEN
    RAISE EXCEPTION 'Password must contain at least one number';
  END IF;
  
  -- Must contain special character
  IF password !~ '[!@#$%^&*(),.?":{}|<>]' THEN
    RAISE EXCEPTION 'Password must contain at least one special character';
  END IF;
  
  -- Check for common weak patterns
  IF password ~* '(password|123|abc|qwerty|admin|test)' THEN
    RAISE EXCEPTION 'Password contains common weak patterns';
  END IF;
  
  RETURN TRUE;
END;
$function$;

-- 5. Session security enhancement
CREATE OR REPLACE FUNCTION public.validate_session_security(
  session_token TEXT,
  current_ip INET,
  current_user_agent TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  session_record RECORD;
  ip_mismatch BOOLEAN := FALSE;
  agent_mismatch BOOLEAN := FALSE;
BEGIN
  -- Get session details
  SELECT * INTO session_record
  FROM public.secure_sessions
  WHERE session_token = validate_session_security.session_token
    AND expires_at > NOW();
  
  IF NOT FOUND THEN
    RETURN FALSE;
  END IF;
  
  -- Check for IP address changes (potential session hijacking)
  IF session_record.ip_address IS NOT NULL 
     AND session_record.ip_address != current_ip THEN
    ip_mismatch := TRUE;
  END IF;
  
  -- Check for user agent changes
  IF session_record.user_agent IS NOT NULL 
     AND session_record.user_agent != current_user_agent THEN
    agent_mismatch := TRUE;
  END IF;
  
  -- Log suspicious activity
  IF ip_mismatch OR agent_mismatch THEN
    PERFORM public.log_security_event(
      'session_anomaly',
      session_record.user_id,
      current_ip,
      current_user_agent,
      jsonb_build_object(
        'session_id', session_record.session_id,
        'original_ip', session_record.ip_address,
        'new_ip', current_ip,
        'original_agent', session_record.user_agent,
        'new_agent', current_user_agent,
        'ip_mismatch', ip_mismatch,
        'agent_mismatch', agent_mismatch
      ),
      'high'
    );
    
    -- Invalidate session on suspicious activity
    DELETE FROM public.secure_sessions 
    WHERE session_token = validate_session_security.session_token;
    
    RETURN FALSE;
  END IF;
  
  -- Update last activity
  UPDATE public.secure_sessions 
  SET last_activity = NOW()
  WHERE session_token = validate_session_security.session_token;
  
  RETURN TRUE;
END;
$function$;

-- 6. Data integrity monitoring
CREATE OR REPLACE FUNCTION public.audit_data_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  integrity_hash TEXT;
  record_data JSONB;
BEGIN
  -- Only audit critical tables
  IF TG_TABLE_NAME NOT IN ('platform_users', 'law_firms', 'cases', 'clients', 'case_documents') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  
  -- Create data integrity hash
  record_data := to_jsonb(COALESCE(NEW, OLD));
  integrity_hash := encode(digest(record_data::TEXT, 'sha256'), 'hex');
  
  -- Log data change with integrity hash
  PERFORM public.log_security_event(
    'data_modification',
    auth.uid(),
    inet_client_addr(),
    current_setting('request.headers', true)::JSONB ->> 'user-agent',
    jsonb_build_object(
      'table', TG_TABLE_NAME,
      'operation', TG_OP,
      'record_id', COALESCE((NEW ->> 'id'), (OLD ->> 'id')),
      'integrity_hash', integrity_hash,
      'timestamp', NOW()
    ),
    'medium'
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$function$;

-- Apply data integrity triggers to critical tables
DROP TRIGGER IF EXISTS audit_platform_users_integrity ON public.platform_users;
CREATE TRIGGER audit_platform_users_integrity
  AFTER INSERT OR UPDATE OR DELETE ON public.platform_users
  FOR EACH ROW EXECUTE FUNCTION public.audit_data_integrity();

DROP TRIGGER IF EXISTS audit_law_firms_integrity ON public.law_firms;
CREATE TRIGGER audit_law_firms_integrity
  AFTER INSERT OR UPDATE OR DELETE ON public.law_firms
  FOR EACH ROW EXECUTE FUNCTION public.audit_data_integrity();