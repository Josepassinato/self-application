-- Security fixes for critical vulnerabilities

-- 1. Fix privilege escalation in platform_users table
-- Drop the overly permissive update policy and create a secure one
DROP POLICY IF EXISTS "Users can update their own record" ON public.platform_users;

-- Create new policy that prevents role escalation
CREATE POLICY "Users can update their own profile (not role)" 
ON public.platform_users 
FOR UPDATE 
USING (auth_user_id = auth.uid())
WITH CHECK (
  auth_user_id = auth.uid() 
  AND (
    -- Only admins can change roles
    (SELECT role FROM public.platform_users WHERE auth_user_id = auth.uid()) = 'admin'
    OR 
    -- Non-admins can't change the role field
    OLD.role = NEW.role
  )
);

-- 2. Fix overly permissive api_usage_logs policy
DROP POLICY IF EXISTS "Allow all operations on api_usage_logs" ON public.api_usage_logs;

-- Create secure policies for api_usage_logs
CREATE POLICY "Users can view their own API usage logs" 
ON public.api_usage_logs 
FOR SELECT 
USING (user_id = auth.uid());

CREATE POLICY "System can create API usage logs" 
ON public.api_usage_logs 
FOR INSERT 
WITH CHECK (true);

-- 3. Fix search_path security issues in database functions
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_user_law_firm_id(user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = user_id LIMIT 1);
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_user_admin(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  RETURN (SELECT role = 'admin' FROM public.platform_users WHERE auth_user_id = user_id LIMIT 1);
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  firm_id uuid;
BEGIN
  -- Use existing firm or create with default firm
  IF NEW.raw_user_meta_data ->> 'law_firm_name' IS NOT NULL THEN
    INSERT INTO public.law_firms (
      name,
      email,
      status
    ) VALUES (
      NEW.raw_user_meta_data ->> 'law_firm_name',
      NEW.email,
      'active'
    ) RETURNING id INTO firm_id;
  ELSE
    -- Use default firm
    firm_id := '550e8400-e29b-41d4-a716-446655440001'::uuid;
  END IF;

  -- Create platform user (default role is 'user', not 'admin' for security)
  INSERT INTO public.platform_users (
    auth_user_id,
    law_firm_id,
    email,
    first_name,
    last_name,
    role
  ) VALUES (
    NEW.id,
    firm_id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data ->> 'first_name', 'Usuário'),
    COALESCE(NEW.raw_user_meta_data ->> 'last_name', ''),
    'user' -- Changed from 'admin' to 'user' for security
  ) ON CONFLICT (auth_user_id) DO UPDATE SET
    email = EXCLUDED.email,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name;

  RETURN NEW;
END;
$function$;

-- 4. Add constraint to prevent direct role manipulation
ALTER TABLE public.platform_users 
ADD CONSTRAINT valid_roles CHECK (role IN ('admin', 'user', 'moderator'));

-- 5. Create audit log for role changes
CREATE TABLE IF NOT EXISTS public.role_change_audit (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  old_role text NOT NULL,
  new_role text NOT NULL,
  changed_by uuid NOT NULL,
  changed_at timestamp with time zone NOT NULL DEFAULT now(),
  reason text
);

ALTER TABLE public.role_change_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can view role changes" 
ON public.role_change_audit 
FOR SELECT 
USING (
  EXISTS (
    SELECT 1 FROM public.platform_users 
    WHERE auth_user_id = auth.uid() AND role = 'admin'
  )
);

-- 6. Create trigger to audit role changes
CREATE OR REPLACE FUNCTION public.audit_role_changes()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF OLD.role != NEW.role THEN
    INSERT INTO public.role_change_audit (
      user_id,
      old_role,
      new_role,
      changed_by,
      reason
    ) VALUES (
      NEW.auth_user_id,
      OLD.role,
      NEW.role,
      auth.uid(),
      'Role changed through platform'
    );
  END IF;
  RETURN NEW;
END;
$function$;

CREATE TRIGGER audit_platform_user_role_changes
  BEFORE UPDATE ON public.platform_users
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_role_changes();