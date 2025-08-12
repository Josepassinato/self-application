-- Phase 1: Critical Security Corrections
-- Fix Supabase functions by adding SET search_path TO ''

-- Update handle_new_platform_user function
CREATE OR REPLACE FUNCTION public.handle_new_platform_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.platform_users (
    auth_user_id,
    law_firm_id,
    email,
    first_name,
    last_name
  ) VALUES (
    NEW.id,
    -- For now, we'll need to handle firm assignment through the app
    -- This trigger just creates the user record
    '00000000-0000-0000-0000-000000000000'::uuid, -- Placeholder, will be updated by app
    NEW.email,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name'
  );
  RETURN NEW;
END;
$function$;

-- Update handle_new_user_signup function  
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

-- Update handle_new_user_profile function
CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.profiles (user_id, first_name, last_name)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name'
  );
  RETURN NEW;
END;
$function$;

-- Update apply_checklist_template function
CREATE OR REPLACE FUNCTION public.apply_checklist_template()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  -- Aplicar template de checklist baseado no tipo de visto
  INSERT INTO public.case_checklists (case_id, template_id, checklist_data)
  SELECT 
    NEW.id,
    ct.id,
    ct.checklist_items
  FROM public.checklist_templates ct
  WHERE ct.is_active = true
    AND NEW.tipo_visto = ANY(ct.visa_types)
    AND ct.law_firm_id IN (
      SELECT pu.law_firm_id 
      FROM public.platform_users pu 
      JOIN public.clients c ON c.responsavel_id = pu.auth_user_id
      WHERE c.id = NEW.client_id
    )
  LIMIT 1;
  
  RETURN NEW;
END;
$function$;

-- Update schedule_case_cleanup function
CREATE OR REPLACE FUNCTION public.schedule_case_cleanup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
$function$;

-- Update create_cleanup_warnings function
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

-- Update accept_client_invitation function
CREATE OR REPLACE FUNCTION public.accept_client_invitation(invitation_token uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  invitation_record RECORD;
  result JSON;
BEGIN
  -- Get invitation details
  SELECT * INTO invitation_record
  FROM public.client_invitations
  WHERE invitation_token = accept_client_invitation.invitation_token
  AND status = 'pending'
  AND expires_at > now();
  
  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'Invalid or expired invitation');
  END IF;
  
  -- Update client with auth user id
  UPDATE public.clients
  SET client_user_id = auth.uid()
  WHERE id = invitation_record.client_id;
  
  -- Mark invitation as accepted
  UPDATE public.client_invitations
  SET 
    status = 'accepted',
    accepted_at = now(),
    auth_user_id = auth.uid()
  WHERE id = invitation_record.id;
  
  RETURN json_build_object(
    'success', true, 
    'client_id', invitation_record.client_id,
    'message', 'Invitation accepted successfully'
  );
END;
$function$;

-- Update get_cases_ready_for_cleanup function
CREATE OR REPLACE FUNCTION public.get_cases_ready_for_cleanup()
RETURNS TABLE(case_id uuid, law_firm_id uuid, case_title text, completion_date date, scheduled_cleanup_date timestamp with time zone)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
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
$function$;

-- Update get_unread_notifications_count function
CREATE OR REPLACE FUNCTION public.get_unread_notifications_count(user_firm_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT COUNT(*)::INTEGER
  FROM public.cleanup_notifications
  WHERE law_firm_id = user_firm_id
    AND is_read = false;
$function$;

-- Update get_user_law_firm_id function
CREATE OR REPLACE FUNCTION public.get_user_law_firm_id(user_id uuid)
RETURNS uuid
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN (SELECT law_firm_id FROM public.platform_users WHERE auth_user_id = user_id LIMIT 1);
END;
$function$;

-- Update is_user_admin function
CREATE OR REPLACE FUNCTION public.is_user_admin(user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  RETURN (SELECT role = 'admin' FROM public.platform_users WHERE auth_user_id = user_id LIMIT 1);
END;
$function$;