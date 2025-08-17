-- Corrigir função audit_data_integrity que está causando erro
DROP FUNCTION IF EXISTS public.audit_data_integrity() CASCADE;

-- Recriar função sem usar digest (não disponível)
CREATE OR REPLACE FUNCTION public.audit_data_integrity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  record_data JSONB;
BEGIN
  -- Only audit critical tables
  IF TG_TABLE_NAME NOT IN ('platform_users', 'law_firms', 'cases', 'clients', 'case_documents') THEN
    RETURN COALESCE(NEW, OLD);
  END IF;
  
  -- Create data record
  record_data := to_jsonb(COALESCE(NEW, OLD));
  
  -- Log data change without integrity hash (digest not available)
  PERFORM public.log_security_event(
    'data_modification',
    auth.uid(),
    inet_client_addr(),
    current_setting('request.headers', true)::JSONB ->> 'user-agent',
    jsonb_build_object(
      'table', TG_TABLE_NAME,
      'operation', TG_OP,
      'record_id', COALESCE((NEW ->> 'id'), (OLD ->> 'id')),
      'timestamp', NOW()
    ),
    'medium'
  );
  
  RETURN COALESCE(NEW, OLD);
END;
$$;