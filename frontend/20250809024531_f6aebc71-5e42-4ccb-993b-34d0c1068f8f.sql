-- Phase C: Security hardening migration
-- 1) Fix views to use SQL SECURITY INVOKER
CREATE OR REPLACE VIEW public.document_analysis_audit_report SQL SECURITY INVOKER AS
SELECT 
  daa.id,
  daa.analysis_id,
  da.document_type,
  da.analysis_type,
  daa.action,
  daa.performed_by,
  ((pu.first_name || ' '::text) || pu.last_name) AS performed_by_name,
  pu.email AS performed_by_email,
  daa.changes_summary,
  daa.created_at,
  da.created_at AS analysis_created_at,
  ((lawyer_pu.first_name || ' '::text) || lawyer_pu.last_name) AS lawyer_name,
  lawyer_pu.email AS lawyer_email
FROM 
  public.document_analysis_audit daa
  LEFT JOIN public.document_analyses da ON daa.analysis_id = da.id
  LEFT JOIN public.platform_users pu ON daa.performed_by = pu.auth_user_id
  LEFT JOIN public.platform_users lawyer_pu ON da.lawyer_user_id = lawyer_pu.auth_user_id
ORDER BY daa.created_at DESC;

CREATE OR REPLACE VIEW public.security_dashboard SQL SECURITY INVOKER AS
SELECT 'authentication_events'::text AS event_category,
       count(*) AS event_count,
       max(security_events.created_at) AS last_event
FROM public.security_events
WHERE security_events.event_type = ANY (ARRAY['login_attempt'::text, 'failed_login'::text, 'password_reset'::text])
  AND security_events.created_at > (now() - interval '24 hours')
UNION ALL
SELECT 'privilege_changes'::text AS event_category,
       count(*) AS event_count,
       max(security_events.created_at) AS last_event
FROM public.security_events
WHERE security_events.event_type = 'role_change'
  AND security_events.created_at > (now() - interval '24 hours')
UNION ALL
SELECT 'failed_operations'::text AS event_category,
       count(*) AS event_count,
       max(security_events.created_at) AS last_event
FROM public.security_events
WHERE security_events.severity = ANY (ARRAY['high','critical'])
  AND security_events.created_at > (now() - interval '24 hours');

-- 2) Add immutable search_path on functions missing it
-- update_law_firm_email_settings_updated_at
CREATE OR REPLACE FUNCTION public.update_law_firm_email_settings_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- update_updated_at_column
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- generate_invoice_number
CREATE OR REPLACE FUNCTION public.generate_invoice_number(firm_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
DECLARE
  prefix text;
  next_number integer;
  invoice_number text;
BEGIN
  -- Buscar configuração do escritório
  SELECT COALESCE(invoice_prefix, 'INV-') INTO prefix
  FROM public.stripe_configurations 
  WHERE law_firm_id = firm_id;
  
  IF prefix IS NULL THEN
    prefix := 'INV-';
  END IF;
  
  SELECT COALESCE(MAX(
    CASE 
      WHEN invoice_number ~ (prefix || '[0-9]+$') 
      THEN CAST(SUBSTRING(invoice_number FROM LENGTH(prefix) + 1) AS INTEGER)
      ELSE 0 
    END
  ), 0) + 1 INTO next_number
  FROM public.invoices 
  WHERE law_firm_id = firm_id;
  
  invoice_number := prefix || LPAD(next_number::text, 6, '0');
  RETURN invoice_number;
END;
$$;