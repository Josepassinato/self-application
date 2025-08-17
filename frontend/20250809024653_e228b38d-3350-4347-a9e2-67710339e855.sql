-- Phase C (partial): Harden functions' search_path (safe and compatible)

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