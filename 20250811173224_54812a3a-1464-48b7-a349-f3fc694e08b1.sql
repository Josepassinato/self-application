-- Security Fix: Add SET search_path TO '' to all functions that need it
-- This prevents potential SQL injection through search_path manipulation

-- Fix function security by adding proper search_path settings
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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

  -- Create platform user
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
    'admin'
  ) ON CONFLICT (auth_user_id) DO UPDATE SET
    email = EXCLUDED.email,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name;

  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (user_id, first_name, last_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'first_name', ''),
    COALESCE(NEW.raw_user_meta_data ->> 'last_name', ''),
    COALESCE(NEW.email, '')
  );
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- Log the error but don't prevent user creation
    RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_cleanup_warnings()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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

-- Secure marketplace RLS policies - remove public access and require authentication
DROP POLICY IF EXISTS "Anyone can view active services" ON public.marketplace_services;

-- Create more secure marketplace access policies
CREATE POLICY "Authenticated users can view verified services" 
ON public.marketplace_services 
FOR SELECT 
TO authenticated
USING (
  is_active = true 
  AND provider_id IN (
    SELECT id FROM public.marketplace_providers 
    WHERE verification_status = 'verified' AND active = true
  )
);

-- Secure platform users role updates - prevent unauthorized role escalation
DROP POLICY IF EXISTS "Users can update their own profile (not role)" ON public.platform_users;

CREATE POLICY "Users can update their own profile (excluding role and firm)" 
ON public.platform_users 
FOR UPDATE 
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (
  auth_user_id = auth.uid() 
  AND law_firm_id = (
    SELECT law_firm_id FROM public.platform_users 
    WHERE auth_user_id = auth.uid()
  )
  AND (
    -- Only admins can change roles
    (SELECT role FROM public.platform_users WHERE auth_user_id = auth.uid()) = 'admin'
    OR role = (SELECT role FROM public.platform_users WHERE auth_user_id = auth.uid())
  )
);

-- Create audit trigger for role changes
CREATE OR REPLACE FUNCTION public.audit_role_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.role != NEW.role THEN
    -- Log role change to audit system
    PERFORM public.log_audit_action(
      auth.uid(),
      'admin',
      'role_change',
      'platform_users',
      NULL,
      NEW.id,
      jsonb_build_object(
        'target_user', NEW.auth_user_id,
        'old_role', OLD.role,
        'new_role', NEW.role,
        'changed_at', now()
      )
    );
  END IF;
  RETURN NEW;
END;
$function$;

-- Create trigger for role change auditing
DROP TRIGGER IF EXISTS audit_role_changes_trigger ON public.platform_users;
CREATE TRIGGER audit_role_changes_trigger
  AFTER UPDATE ON public.platform_users
  FOR EACH ROW
  EXECUTE FUNCTION public.audit_role_changes();

-- Improve marketplace provider access
CREATE POLICY "Only verified providers can create services"
ON public.marketplace_services
FOR INSERT
TO authenticated
WITH CHECK (
  provider_id IN (
    SELECT id FROM public.marketplace_providers 
    WHERE verification_status = 'verified' 
    AND active = true
    AND law_firm_id IN (
      SELECT law_firm_id FROM public.platform_users 
      WHERE auth_user_id = auth.uid()
    )
  )
);