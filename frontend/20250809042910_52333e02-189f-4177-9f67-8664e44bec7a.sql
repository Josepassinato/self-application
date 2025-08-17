-- Harden function created in previous migration by setting search_path
CREATE OR REPLACE FUNCTION public.update_import_jobs_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;