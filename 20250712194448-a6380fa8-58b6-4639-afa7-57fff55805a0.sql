-- Create a function to handle new platform user creation with law firm
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  firm_id uuid;
BEGIN
  -- Create law firm first if law_firm_name is provided
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
    -- Use placeholder firm if no law firm name
    firm_id := '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  -- Create platform user with proper law firm association
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
    NEW.raw_user_meta_data ->> 'first_name',
    NEW.raw_user_meta_data ->> 'last_name',
    'admin' -- First user in a firm is admin
  );

  RETURN NEW;
END;
$$;

-- Drop the old trigger if it exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Create new trigger
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_signup();