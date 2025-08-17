-- Create a default law firm if it doesn't exist
INSERT INTO public.law_firms (
  id,
  name,
  email,
  status
) VALUES (
  '550e8400-e29b-41d4-a716-446655440001',
  'Escritório Demo',
  'admin@demo.com',
  'active'
) ON CONFLICT (id) DO NOTHING;

-- Create or update the platform user creation trigger
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- Drop existing trigger if it exists and create new one
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user_signup();